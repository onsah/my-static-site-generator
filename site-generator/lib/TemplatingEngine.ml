open! Core
module Sequence = MySequence
module Map = Core.Map.Poly

type context_item =
  | String of String.t
  | Number of float

type context = (string, context_item) Map.t

module Tokenizer = struct
  type token =
    | Text of string
    | LeftCurly
    | RightCurly
  [@@deriving sexp, compare]

  let show = function
    | Text text -> text
    | LeftCurly -> "{{"
    | RightCurly -> "}}"
  ;;

  type error =
    [ `TokenizerExpectedOneOf of char list
    | `TokenizerUnexpected of char
    ]
  [@@deriving sexp, compare]

  let tokenize string : (token Sequence.t, [> error ]) result =
    let open struct
      exception TokenizerExpectedOneOf of char list
      exception TokenizerUnexpected of char
    end in
    let computation yield =
      let rec main chars =
        match chars with
        | [] -> ()
        | c :: cs ->
          (match c with
           | '{' -> left_curly cs
           | '}' -> right_curly cs
           | 'a' .. 'z' | 'A' .. 'Z' -> identifier cs (String.of_char c)
           | _ -> raise (TokenizerUnexpected c))
      and left_curly chars =
        match chars with
        | '{' :: cs ->
          yield LeftCurly;
          main cs
        | c :: _ -> raise (TokenizerUnexpected c)
        | [] -> raise (TokenizerExpectedOneOf [ '{' ])
      and right_curly chars =
        match chars with
        | '}' :: cs ->
          yield RightCurly;
          main cs
        | c :: _ -> raise (TokenizerUnexpected c)
        | [] -> raise (TokenizerExpectedOneOf [ '}' ])
      and identifier chars id =
        match chars with
        | [] -> yield (Text id)
        | c :: cs ->
          (match c with
           | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> identifier cs (id ^ String.of_char c)
           | _ ->
             yield (Text id);
             main chars)
      in
      main (String.to_list string)
    in
    try Ok (Sequence.of_iterator computation) with
    | TokenizerExpectedOneOf chars -> Error (`TokenizerExpectedOneOf chars)
    | TokenizerUnexpected char -> Error (`TokenizerUnexpected char)
  ;;

  let%test_unit "tokenizer_basic" =
    let string = "{{foo}}" in
    let result = tokenize string |> Result.map ~f:Sequence.to_list in
    [%test_eq: (token list, error) result]
      result
      (Ok [ LeftCurly; Text "foo"; RightCurly ])
  ;;
end

module Templating = struct
  type error =
    [ `Unexpected of string
    | `VariableNotFound of string
    | `FinishedUnexpectedly
    ]
  [@@deriving sexp, compare]

  let perform ~tokens (context : context) : (string Sequence.t, [> error ]) result =
    let open Tokenizer in
    let open struct
      exception Unexpected of token
      exception VariableNotFound of string
      exception FinishedUnexpectedly
    end in
    let computation yield =
      let rest tokens = Sequence.tl tokens |> Option.value ~default:Sequence.empty in
      let rec default tokens =
        match Sequence.hd tokens with
        | Some LeftCurly -> right_curly (rest tokens)
        | Some RightCurly -> raise (Unexpected RightCurly)
        | Some (Text s) -> yield s
        | None -> ()
      and right_curly tokens =
        match Sequence.hd tokens with
        | Some LeftCurly -> raise (Unexpected LeftCurly)
        | Some (Text s) -> text s (rest tokens)
        | Some RightCurly -> raise (Unexpected Tokenizer.RightCurly)
        | None -> raise FinishedUnexpectedly
      and text text tokens =
        match Map.find context text with
        | Some value ->
          let replaced_text =
            match value with
            | String s -> s
            | Number n -> string_of_float n
          in
          yield replaced_text;
          left_curly tokens
        | None -> raise (VariableNotFound text)
      and left_curly tokens =
        match Sequence.hd tokens with
        | Some RightCurly -> default (rest tokens)
        | Some (Text _ as token) | Some (LeftCurly as token) -> raise (Unexpected token)
        | None -> raise FinishedUnexpectedly
      in
      default tokens
    in
    try Ok (Sequence.of_iterator computation) with
    | Unexpected token -> Error (`Unexpected (token |> Tokenizer.show))
    | VariableNotFound id -> Error (`VariableNotFound id)
    | FinishedUnexpectedly -> Error `FinishedUnexpectedly
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
        let open Tokenizer in
        let tokens = Sequence.of_list [ LeftCurly; Text s1; RightCurly ] in
        let context = Map.of_alist_exn [ s1, String s2 ] in
        let result = perform ~tokens context in
        let actual = result |> Result.ok |> Option.value_exn |> Sequence.to_list in
        let expected = [ s2 ] in
        [%test_eq: string list] actual expected)
  ;;

  let%test_unit "perform_templating_string_float" =
    Quickcheck.test
      ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (s1, s2) ->
        let open Tokenizer in
        let tokens = Sequence.of_list [ LeftCurly; Text s1; RightCurly ] in
        let context = Map.of_alist_exn [ s1, String s2 ] in
        let result = perform ~tokens context in
        let actual = result |> Result.ok |> Option.value_exn |> Sequence.to_list in
        let expected = [ s2 ] in
        [%test_eq: string list] actual expected)
  ;;
end

type templating_error_kind =
  [ Tokenizer.error
  | Templating.error
  ]
[@@deriving sexp, compare]

type position =
  { line : int
  ; column : int
  }
[@@deriving sexp, compare]

type templating_error =
  { kind : templating_error_kind
  ; position : position
  }
[@@deriving sexp, compare]

type html_document = Soup.soup Soup.node

(* Traverses the document and performs templating on text nodes *)
let run ~(doc : html_document) ~(context : context) =
  let open Result.Let_syntax in
  let parser = Soup.to_string doc |> Markup.string |> Markup.parse_html in
  let map_signal =
    let perform_templating string (context : context) =
      let%bind tokens = Tokenizer.tokenize string in
      let%map strings = Templating.perform ~tokens context in
      strings |> Sequence.to_list |> String.concat
    and add_position_to_error error =
      let line, column = Markup.location parser in
      { kind = error; position = { line; column } }
    in
    function
    | `Text strs ->
      let joined_str = String.concat strs in
      perform_templating joined_str context
      |> Result.map ~f:(fun str -> `Text [ str ])
      |> Result.map_error ~f:add_position_to_error
    | x -> Ok x
  in
  let stream = Markup.signals parser in
  let stream = Markup.map map_signal stream in
  let%map items = stream |> Markup.to_list |> Result.combine_errors in
  items |> Markup.of_list |> Soup.from_signals
;;

let%test_unit "perform_templating_error_location" =
  let doc = Soup.parse "<html><head></head><body>{{/}}</body></html>" in
  let context = Map.empty in
  let result = run ~doc ~context in
  match result with
  | Error [ { position; kind } ] ->
    [%test_eq: templating_error_kind] kind (`TokenizerUnexpected '/');
    [%test_eq: position] position { line = 1; column = 26 }
  | Ok _ | Error _ -> assert false
;;
