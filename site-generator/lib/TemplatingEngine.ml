open! Core
module Sequence = MySequence
module Map = Core.Map.Poly

type context_item =
  | String of string
  | Number of float

type context = (string, context_item) Map.t

type location =
  { line : int
  ; column : int
  }
[@@deriving sexp, compare]

module Location = struct
  let add_col loc ~amount = { loc with column = loc.column + amount }
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

  type error =
    [ `TokenizerExpectedOneOf of char list * location
    | `TokenizerUnexpected of char * location
    ]
  [@@deriving sexp, compare]

  let end_location { kind; location } =
    let amount =
      match kind with
      | LeftCurly | RightCurly -> 2
      | Text text -> String.length text
    in
    Location.add_col location ~amount
  ;;

  let with_location chars : (char * location) Sequence.t =
    Sequence.folding_map
      chars
      ~init:{ line = 0; column = 0 }
      ~f:(fun ({ line; column } as loc) char ->
        let next_loc =
          match char with
          | '\n' -> { line = line + 1; column = 0 }
          | _ -> { line; column = column + 1 }
        in
        next_loc, (char, loc))
  ;;

  let iter (chars : char Sequence.t) (f : token -> unit) (abort : error -> unit) : unit =
    let rec default chars =
      match Sequence.next chars with
      | Some (((char, location) as char_loc), chars) ->
        (match char with
         | '{' -> left_curly chars ~start_location:location
         | '}' -> right_curly chars ~start_location:location
         | 'a' .. 'z' | 'A' .. 'Z' | '<' | '>' | '/' ->
           text chars (String.of_char char) ~start_location:location
         | _ -> abort (`TokenizerUnexpected char_loc))
      | None -> ()
    and left_curly chars ~start_location =
      match Sequence.next chars with
      | Some (('{', _), chars) ->
        f { kind = LeftCurly; location = start_location };
        default chars
      | Some (c, _) -> abort (`TokenizerUnexpected c)
      | None ->
        abort (`TokenizerExpectedOneOf ([ '{' ], Location.increment_col start_location))
    and right_curly chars ~start_location =
      match Sequence.next chars with
      | Some (('}', _), chars) ->
        f { kind = RightCurly; location = start_location };
        default chars
      | Some (c, _) -> abort (`TokenizerUnexpected c)
      | None ->
        abort (`TokenizerExpectedOneOf ([ '}' ], Location.increment_col start_location))
    and text chars acc ~start_location =
      match Sequence.next chars with
      | None ->
        f { kind = Text acc; location = start_location };
        ()
      | Some (((char, _) as char_with_loc), chars) ->
        (match char with
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '<' | '>' | '/' ->
           text chars (acc ^ String.of_char char) ~start_location
         | _ ->
           f { kind = Text acc; location = start_location };
           default (Sequence.shift_right chars char_with_loc))
    in
    chars |> with_location |> default
  ;;

  let tokenize (chars : char Sequence.t) : (token Sequence.t, [> error ]) result =
    (Sequence.of_fallible_iterator (iter chars)
      : (token Sequence.t, error) result
      :> (token Sequence.t, [> error ]) result)
  ;;

  let%test_unit "tokenizer_basic" =
    let string = "{{foo}}" in
    let result =
      string |> String.to_sequence |> tokenize |> Result.map ~f:Sequence.to_list
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
      string |> String.to_sequence |> tokenize |> Result.map ~f:Sequence.to_list
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
  type error =
    [ `TemplatingUnexpected of Tokenizer.kind * location
    | `TemplatingVariableNotFound of string * location
    | `TemplatingFinishedUnexpectedly of location
    ]
  [@@deriving sexp, compare]

  let iter
        (tokens : Tokenizer.token Sequence.t)
        (context : context)
        (f : string -> unit)
        (abort : error -> unit)
    : unit
    =
    let rec default tokens =
      match Sequence.next tokens with
      | Some ((Tokenizer.{ kind; location } as token), tokens) ->
        (match kind with
         | LeftCurly -> variable tokens ~prev_location:(Tokenizer.end_location token)
         | RightCurly -> abort (`TemplatingUnexpected (kind, location))
         | Text s ->
           f s;
           default tokens)
      | None -> ()
    and variable tokens ~prev_location =
      match Sequence.next tokens with
      | Some ((Tokenizer.{ kind; location } as token), tokens) ->
        (match kind with
         | Text text ->
           if not (String.for_all text ~f:(fun c -> Char.is_alphanum c))
           then abort (`TemplatingUnexpected (kind, location));
           (match Map.find context text with
            | Some value ->
              let replaced_text =
                match value with
                | String s -> s
                | Number n -> string_of_float n
              in
              f replaced_text;
              right_curly tokens ~prev_location:Tokenizer.(end_location token)
            | None -> abort (`TemplatingVariableNotFound (text, location)))
         | LeftCurly | RightCurly -> abort (`TemplatingUnexpected (kind, location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and right_curly tokens ~prev_location =
      match Sequence.next tokens with
      | Some ({ kind; location }, tokens) ->
        (match kind with
         | RightCurly -> default tokens
         | LeftCurly | Text _ -> abort (`TemplatingUnexpected (kind, location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    in
    default tokens
  ;;

  let perform ~(tokens : Tokenizer.token Sequence.t) (context : context)
    : (string Sequence.t, [> error ]) result
    =
    (Sequence.of_fallible_iterator (iter tokens context)
      : (string Sequence.t, error) result
      :> (string Sequence.t, [> error ]) result)
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

type error =
  [ Tokenizer.error
  | Templating.error
  ]
[@@deriving sexp, compare]

let show_error error =
  match error with
  | _ -> failwith "TODO"
;;

let error_location _ = failwith "TODO"

let run ~(template : string) ~(context : context) =
  let open Result.Let_syntax in
  let%bind tokens = Tokenizer.tokenize (template |> String.to_sequence) in
  let%map strings = Templating.perform ~tokens context in
  strings |> Sequence.to_list |> String.concat
;;

let%test_unit "perform_templating_error_location" =
  let template = "<html><head></head><body>{{/}}</body></html>" in
  let context = Map.empty in
  let actual = run ~template ~context in
  let expected =
    Error (`TemplatingUnexpected (Tokenizer.Text "/", { line = 0; column = 27 }))
  in
  [%test_eq: (string, error) result] actual expected
;;
