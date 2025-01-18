open! Core

type context_item = String of String.t | Number of float
type context = (string, context_item, String.comparator_witness) Map.t

type templating_error_kind = [ `UnexpectedCharacter of char | `EmptyIdentifier ]
[@@deriving sexp, compare]

type position = { line : int; column : int } [@@deriving sexp, compare]

type templating_error = { kind : templating_error_kind; position : position }
[@@deriving sexp, compare]

exception UnexpectedCharacter of char
exception EmptyIdentifier

let perform_templating_string string (context : context) =
  let open Result in
  let open struct
    type state =
      | Default
      | OpenCurly
      | ScanningStart
      | ScanningContinue
      | CloseCurly1
  end in
  let result = Buffer.create (String.length string) in
  let current = Buffer.create 10 in
  let state = ref Default in
  let result =
    try_with (fun () ->
        String.iter string ~f:(fun c ->
            match !state with
            | Default -> (
                match c with
                | '{' -> state := OpenCurly
                | c -> Buffer.add_char result c)
            | OpenCurly -> (
                match c with
                | '{' ->
                    Buffer.clear current;
                    state := ScanningStart
                | c ->
                    (* '{' we saw before is also a normal character *)
                    Buffer.add_char result '{';
                    Buffer.add_char result c;
                    state := Default)
            | ScanningStart -> (
                match c with
                | 'a' .. 'z' | 'A' .. 'Z' ->
                    Buffer.add_char current c;
                    state := ScanningContinue
                | '}' -> raise EmptyIdentifier
                | _ -> raise (UnexpectedCharacter c))
            | ScanningContinue -> (
                match c with
                | '}' -> state := CloseCurly1
                | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' ->
                    Buffer.add_char current c
                | c -> raise (UnexpectedCharacter c))
            | CloseCurly1 -> (
                match c with
                | '}' ->
                    let key = Buffer.contents current in
                    let lookup = Map.find_exn context key in
                    let value =
                      match lookup with
                      | String text -> text
                      | Number n -> string_of_float n
                    in
                    Buffer.add_string result value;
                    Buffer.clear current;
                    state := Default
                (* We didn't close it yet *)
                | c -> raise (UnexpectedCharacter c)));
        Buffer.contents result)
  in
  match result with
  | Ok string -> Ok string
  | Error (UnexpectedCharacter c) -> Error (`UnexpectedCharacter c)
  | Error EmptyIdentifier -> Error `EmptyIdentifier
  | Error e -> raise e

let%test_unit "perform_templating_string_basic" =
  let open String in
  let string = "{{foo}}" in
  let context = Map.of_alist_exn [ ("foo", String "bar") ] in
  let result = perform_templating_string string context in
  [%test_eq: (string, templating_error_kind) result] result (Ok "bar")

let%test_unit "perform_templating_string_empty_identifier" =
  let context = Map.empty (module String) in
  let result = perform_templating_string "{{}}" context in
  [%test_eq: (string, templating_error_kind) result] result (Error `EmptyIdentifier)

let str_generator =
  let first = Quickcheck.Generator.char_alpha in
  let rest = String.gen_with_length 4 Quickcheck.Generator.char_alphanum in
  Quickcheck.Generator.map2 first rest ~f:(sprintf "%c%s")

let%test_unit "perform_templating_string_alphanum" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator) ~f:(fun (s1, s2) ->
      let open String in
      let string = sprintf "{{%s}}" s1 in
      let context = Map.of_alist_exn [ (s1, String s2) ] in
      let result = perform_templating_string string context in
      let expected = s2 in
      [%test_eq: (string, templating_error_kind) result] result (Ok expected))

let%test_unit "perform_templating_string_float" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator) ~f:(fun (s1, s2) ->
      let open String in
      let string = sprintf "{{%s}}" s1 in
      let context = Map.of_alist_exn [ (s1, String s2) ] in
      let result = perform_templating_string string context in
      let expected = s2 in
      [%test_eq: (string, templating_error_kind) result] result (Ok expected))

let flatten_list nested_list = List.bind nested_list ~f:Fun.id

type html_document = Soup.soup Soup.node

(* Traverses the document and performs templating on text nodes *)
let perform_templating ~(doc : html_document) ~(context : context) =
  let open Markup in
  let html_string = Soup.to_string doc in
  let parser = html_string |> Markup.string |> Markup.parse_html in
  let stream = Markup.signals parser in
  let stream =
    map
      (function
        | `Text strs -> (
            let results =
              List.map strs ~f:(fun str ->
                  perform_templating_string str context)
            in
            match Result.combine_errors results with
            | Ok strs -> Ok (`Text strs)
            | Error errors ->
                let position =
                  let line, column = Markup.location parser in
                  { line; column }
                in
                let errors =
                  List.map errors ~f:(fun kind -> { kind; position })
                in
                Error errors)
        | x -> Ok x)
      stream
  in
  let templating_results = Markup.to_list stream in
  match Result.combine_errors templating_results with
  | Ok items -> Ok (Soup.from_signals (Markup.of_list items))
  | Error errors -> Error (flatten_list errors)

let%test_unit "perform_templating_error_location" =
  let doc = Soup.parse "<html><head></head><body>{{/}}</body></html>" in
  let context = Map.empty (module String) in
  let result = perform_templating ~doc ~context in
  match result with
  | Error [ { position; kind } ] ->
      [%test_eq: templating_error_kind] kind (`UnexpectedCharacter '/');
      [%test_eq: position] position { line = 1; column = 26 }
  | Ok _ | Error _ -> assert false
