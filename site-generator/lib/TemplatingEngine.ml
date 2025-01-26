open! Core
module Sequence = MySequence
module Map = Core.Map.Poly

type context_item =
  | String of String.t
  | Number of float

type context = (string, context_item) Map.t

type location =
  { line : int
  ; column : int
  }
[@@deriving sexp, compare]

module Location = struct
  let with_location string : (char * location) Sequence.t =
    string
    |> String.to_sequence
    |> Sequence.folding_map
         ~init:{ line = 0; column = 0 }
         ~f:(fun ({ line; column } as loc) char ->
           let next_loc =
             match char with
             | '\n' -> { line = line + 1; column = 0 }
             | _ -> { line; column = column + 1 }
           in
           next_loc, (char, loc))
  ;;

  let add_col { line; column } ~amount = { line; column = column + amount }
  let increment_col = add_col ~amount:1
end

module Tokenizer = struct
  type kind =
    | Text of string
    | LeftCurly
    | RightCurly
  [@@deriving sexp, compare]

  type token =
    { kind : kind
    ; location : location
    }
  [@@deriving sexp, compare]

  let end_location { kind; location = { line; column } } =
    let offset =
      match kind with
      | LeftCurly | RightCurly -> 2
      | Text text -> String.length text
    in
    { line; column = column + offset }
  ;;

  let show = function
    | Text text -> text
    | LeftCurly -> "{{"
    | RightCurly -> "}}"
  ;;

  type error_kind =
    [ `TokenizerExpectedOneOf of char list
    | `TokenizerUnexpected of char
    ]
  [@@deriving sexp, compare]

  type error =
    { error_kind : error_kind
    ; location : location
    }
  [@@deriving sexp, compare]

  let tokenize (chars_with_location : (char * location) Sequence.t)
    : (token Sequence.t, error) result
    =
    let open struct
      exception TokenizerExpectedOneOf of (char list * location)
      exception TokenizerUnexpected of (char * location)
    end in
    let computation yield =
      let rec main chars =
        match Sequence.next chars with
        | Some (((char, location) as char_loc), rest) ->
          (match char with
           | '{' -> left_curly rest ~start_location:location
           | '}' -> right_curly rest ~start_location:location
           | 'a' .. 'z' | 'A' .. 'Z' | '<' | '>' | '/' ->
             text rest (String.of_char char) location
           | _ -> raise (TokenizerUnexpected char_loc))
        | None -> ()
      and left_curly chars ~start_location =
        match Sequence.next chars with
        | Some (('{', _), rest) ->
          yield { kind = LeftCurly; location = start_location };
          main rest
        | Some (c, _) -> raise (TokenizerUnexpected c)
        | None ->
          raise (TokenizerExpectedOneOf ([ '{' ], Location.increment_col start_location))
      and right_curly chars ~start_location =
        match Sequence.next chars with
        | Some (('}', _), rest) ->
          yield { kind = RightCurly; location = start_location };
          main rest
        | Some (c, _) -> raise (TokenizerUnexpected c)
        | None ->
          raise (TokenizerExpectedOneOf ([ '}' ], Location.increment_col start_location))
      and text chars id location =
        match Sequence.next chars with
        | None -> yield { kind = Text id; location }
        | Some ((char, _), rest) ->
          (match char with
           | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '<' | '>' | '/' ->
             text rest (id ^ String.of_char char) location
           | _ ->
             yield { kind = Text id; location };
             main chars)
      in
      main chars_with_location
    in
    try Ok (Sequence.of_iterator computation) with
    | TokenizerExpectedOneOf (chars, location) ->
      Error { error_kind = `TokenizerExpectedOneOf chars; location }
    | TokenizerUnexpected (char, location) ->
      Error { error_kind = `TokenizerUnexpected char; location }
  ;;

  let%test_unit "tokenizer_basic" =
    let string = "{{foo}}" in
    let result =
      string |> Location.with_location |> tokenize |> Result.map ~f:Sequence.to_list
    in
    [%test_eq: (token list, error) result]
      result
      (Ok
         [ { kind = LeftCurly; location = { line = 0; column = 0 } }
         ; { kind = Text "foo"; location = { line = 0; column = 2 } }
         ; { kind = RightCurly; location = { line = 0; column = 5 } }
         ])
  ;;

  let%test_unit "tokenizer_left_angle" =
    let string = "<{{foo}}" in
    let result =
      string |> Location.with_location |> tokenize |> Result.map ~f:Sequence.to_list
    in
    [%test_eq: (token list, error) result]
      result
      (Ok
         [ { kind = Text "<"; location = { line = 0; column = 0 } }
         ; { kind = LeftCurly; location = { line = 0; column = 1 } }
         ; { kind = Text "foo"; location = { line = 0; column = 3 } }
         ; { kind = RightCurly; location = { line = 0; column = 6 } }
         ])
  ;;
end

module Templating = struct
  type error_kind =
    [ `Unexpected of string
    | `VariableNotFound of string
    | `FinishedUnexpectedly
    ]
  [@@deriving sexp, compare]

  type error =
    { error_kind : error_kind
    ; location : location
    }
  [@@deriving sexp, compare]

  let perform ~(tokens : Tokenizer.token Sequence.t) (context : context)
    : (string Sequence.t, error) result
    =
    let open struct
      exception TokenizerException of error
    end in
    let computation yield =
      let rec default (tokens : Tokenizer.token Sequence.t) =
        match Sequence.next tokens with
        | Some (({ kind; location } as token), tokens) ->
          (match kind with
           | LeftCurly -> variable tokens ~prev_location:(Tokenizer.end_location token)
           | RightCurly ->
             raise
               (TokenizerException
                  { error_kind = `Unexpected (kind |> Tokenizer.show); location })
           | Text s ->
             yield s;
             default tokens)
        | None -> ()
      and variable tokens ~prev_location =
        match Sequence.next tokens with
        | Some (({ kind; location } as token), tokens) ->
          (match kind with
           | Text text ->
             if not (String.for_all text ~f:(fun c -> Char.is_alphanum c))
             then raise (TokenizerException { error_kind = `Unexpected text; location });
             (match Map.find context text with
              | Some value ->
                let replaced_text =
                  match value with
                  | String s -> s
                  | Number n -> string_of_float n
                in
                yield replaced_text;
                right_curly tokens ~prev_location:Tokenizer.(end_location token)
              | None ->
                raise
                  (TokenizerException { error_kind = `VariableNotFound text; location }))
           | LeftCurly | RightCurly ->
             raise
               (TokenizerException
                  { error_kind = `Unexpected (kind |> Tokenizer.show); location }))
        | None ->
          raise
            (TokenizerException
               { error_kind = `FinishedUnexpectedly; location = prev_location })
      and right_curly tokens ~prev_location =
        match Sequence.next tokens with
        | Some ({ kind; location }, tokens) ->
          (match kind with
           | RightCurly -> default tokens
           | LeftCurly | Text _ ->
             raise
               (TokenizerException
                  { error_kind = `Unexpected (kind |> Tokenizer.show); location }))
        | None ->
          raise
            (TokenizerException
               { error_kind = `FinishedUnexpectedly; location = prev_location })
      in
      default tokens
    in
    try Ok (Sequence.of_iterator computation) with
    | TokenizerException error -> Error error
  ;;

  (* TESTS *)

  let str_generator =
    let first = Quickcheck.Generator.char_alpha in
    let rest = String.gen_with_length 4 Quickcheck.Generator.char_alphanum in
    Quickcheck.Generator.map2 first rest ~f:(sprintf "%c%s")
  ;;

  let%test_unit "perform_templating_string_alphanum" =
    Quickcheck.test
      ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (s1, s2) ->
        let tokens =
          Tokenizer.(
            Sequence.of_list [ LeftCurly; Text s1; RightCurly ]
            |> Sequence.map ~f:(fun kind -> { kind; location = { line = 0; column = 0 } }))
        in
        let context = Map.of_alist_exn [ s1, String s2 ] in
        let result = perform ~tokens context in
        let actual = result |> Result.map ~f:Sequence.to_list in
        let expected = Ok [ s2 ] in
        [%test_eq: (string list, error) result] actual expected)
  ;;

  let%test_unit "perform_templating_string_float" =
    Quickcheck.test
      ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (s1, s2) ->
        let open Tokenizer in
        let tokens =
          Sequence.of_list [ LeftCurly; Text s1; RightCurly ]
          |> Sequence.map ~f:(fun kind -> { kind; location = { line = 0; column = 0 } })
        in
        let context = Map.of_alist_exn [ s1, String s2 ] in
        let result = perform ~tokens context in
        let actual = result |> Result.ok |> Option.value_exn |> Sequence.to_list in
        let expected = [ s2 ] in
        [%test_eq: string list] actual expected)
  ;;
end

type templating_error_kind =
  [ Tokenizer.error_kind
  | Templating.error_kind
  ]
[@@deriving sexp, compare]

type templating_error =
  { kind : templating_error_kind
  ; position : location
  }
[@@deriving sexp, compare]

type html_document = Soup.soup Soup.node

(* Traverses the document and performs templating on text nodes *)
let run ~(template : string) ~(context : context) =
  let open Result.Let_syntax in
  let chars_with_locations = template |> Location.with_location in
  let%bind tokens =
    Tokenizer.tokenize chars_with_locations
    |> Result.map_error ~f:(fun (error : Tokenizer.error) ->
      { kind = (error.error_kind : Tokenizer.error_kind :> templating_error_kind)
      ; position = error.location
      })
  in
  let%map strings =
    Templating.perform ~tokens context
    |> Result.map_error ~f:(fun (error : Templating.error) ->
      { kind = (error.error_kind : Templating.error_kind :> templating_error_kind)
      ; position = error.location
      })
  in
  Sequence.fold strings ~init:"" ~f:String.append
;;

let%test_unit "perform_templating_error_location" =
  let template = "<html><head></head><body>{{/}}</body></html>" in
  let context = Map.empty in
  let actual = run ~template ~context in
  let expected = Error { kind = `Unexpected "/"; position = { line = 0; column = 27 } } in
  [%test_eq: (string, templating_error) result] actual expected
;;
