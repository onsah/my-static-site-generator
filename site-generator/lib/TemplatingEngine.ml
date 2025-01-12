open! Core

type html_document = Soup.soup Soup.node

type context_item =
    | String of String.t
    | Number of float

type context = (string, context_item, String.comparator_witness) Map.t

let perform_templating_string _ _ =
  (* TODO: match with regex {{[a-zA-Z0-9-_]+}} with middle part being extracted and replae it using context*)
  "{{bar}}"

let%test_unit "perform_templating_string_basic" =
  let open String in
  let string = "{{foo}}" in
  let context = Map.of_alist_exn ["foo", String "bar"] in
  let result = perform_templating_string string context in
  [%test_eq: string] result "{{bar}}"

let%test_unit "perform_templating_string_alphanumeric" =
  let str_generator = String.gen_with_length 5 Char.quickcheck_generator in
  Quickcheck.test
  (Quickcheck.Generator.both str_generator str_generator)
    ~f:(fun (s1, s2) -> 
        let open String in
        let string = sprintf "{{%s}}" s1 in
        let context = Map.of_alist_exn [s1, String s2] in
        let result = perform_templating_string string context in
        let expected = sprintf "{{%s}}" s2 in
        [%test_eq: string] result expected)

(* Traverses the document and performs templating on text nodes *)
let perform_templating ~(doc : html_document) ~(context : context) =
  let open Markup in
  let stream = Soup.signals doc in
  let stream = map 
    (function 
      | `Text str -> `Text [(perform_templating_string str context)]
      | x -> x) 
    stream in
  stream |> Soup.from_signals


