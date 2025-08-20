open! Core
module Sequence = MySequence
module Map = Core.Map.Poly
open Context

type error =
  [ Tokenizer.error
  | Parser.error
  | Subst.error
  ]
[@@deriving sexp, compare]

let show_error (error : error) =
  match error with
  | (`TokenizerExpectedOneOf _ | `TokenizerUnexpected _) as error ->
      Tokenizer.show_error error
  | (`ParserFinishedUnexpectedly _ | `ParserUnexpected _) as error ->
      Parser.show_error error
  | ( `TemplatingExpectedType _
    | `TemplatingVariableNotFound _
    | `TemplatingUnexpectedType _ ) as error -> Subst.show_error error

let error_location : error -> Location.t = function
  | `TokenizerExpectedOneOf (_, location)
  | `TokenizerUnexpected (_, location)
  | `ParserFinishedUnexpectedly location
  | `ParserUnexpected { start_location = location; _ }
  | `TemplatingExpectedType { location; _ }
  | `TemplatingUnexpectedType { location; _ }
  | `TemplatingVariableNotFound (_, location) -> location

let run ~(template : string) ~(context : context) =
  let open Result.Let_syntax in
  let chars = String.to_sequence template in
  let%bind tokens = Tokenizer.tokenize chars |> Sequence.flatten_result in
  let%bind nodes = Parser.parse (tokens |> Sequence.of_list) in
  Subst.subst (nodes |> Sequence.of_list) ~context

let%test_unit "perform_templating_error_location" =
  let template = "<html><head></head><body>{{/}}</body></html>" in
  let context = Map.empty in
  let actual = run ~template ~context in
  let expected =
    Error
      (`ParserUnexpected
         Tokenizer.
           {
             kind = Tokenizer.Text "/";
             start_location = Location.make ~line:0 ~column:27;
             end_location = Location.make ~line:0 ~column:28;
           })
  in
  [%test_eq: (string, error) result] actual expected

let%test_unit "perform_templating_error_location" =
  let template = "<html><head></head><body>{{foo./}}</body></html>" in
  let context = Map.empty in
  let actual = run ~template ~context in
  let expected =
    Error
      (`ParserUnexpected
         Tokenizer.
           {
             kind = Tokenizer.Text "/";
             start_location = Location.make ~line:0 ~column:31;
             end_location = Location.make ~line:0 ~column:32;
           })
  in
  [%test_eq: (string, error) result] actual expected

let str_generator =
  let first = Quickcheck.Generator.char_alpha in
  let rest = String.gen_with_length 4 Quickcheck.Generator.char_alphanum in
  Quickcheck.Generator.map2 first rest ~f:(sprintf "%c%s")

let floats_generator n = List.gen_with_length n Float.gen_finite

let%test_unit "perform_templating_string_alphanum" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator) ~f:(fun (s1, s2) ->
      let template = sprintf "{{%s}}" s1 in
      let context = Map.of_alist_exn [ (s1, String s2) ] in
      let actual = run ~template ~context in
      let expected = Ok s2 in
      [%test_eq: (string, error) result] actual expected)

let%test_unit "perform_templating_string_float" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator) ~f:(fun (s1, s2) ->
      let template = sprintf "{{%s}}" s1 in
      let context = Map.of_alist_exn [ (s1, String s2) ] in
      let actual = run ~template ~context in
      let expected = Ok s2 in
      [%test_eq: (string, error) result] actual expected)

let%test_unit "perform_templating_foreach" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.map3 str_generator str_generator (floats_generator 10)
       ~f:(fun x y z -> (x, y, z)))
    ~f:(fun (collection_name, item_name, items) ->
      let template =
        sprintf "{{foreach %s in %s{{%s}}end}}" item_name collection_name
          item_name
      in
      let context =
        Map.of_alist_exn
          [
            ( collection_name,
              Collection (items |> List.map ~f:(fun i -> Number i)) );
          ]
      in
      let actual = run ~template ~context in
      let expected =
        items |> List.map ~f:string_of_float |> String.concat |> Result.return
      in
      [%test_eq: (string, error) result] actual expected)

let%test_unit "perform_templating_foreach_unexpected_type" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator)
    ~f:(fun (var_name, collection_name) ->
      let template =
        sprintf "{{foreach %s in %s end}}" var_name collection_name
      in
      let context = Map.of_alist_exn [ (collection_name, Number 0.) ] in
      let actual = run ~template ~context in
      let expected =
        Error
          (`TemplatingExpectedType
             Subst.
               {
                 typ = Collection_t;
                 location = Location.make ~line:0 ~column:2;
               })
      in
      [%test_eq: (string, error) result] actual expected)

let%test_unit "perform_templating_object" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.map3 str_generator str_generator
       Float.quickcheck_generator ~f:(fun x y z -> (x, y, z)))
    ~f:(fun (obj_name, field_name, value) ->
      let template = sprintf "{{%s.%s}}" obj_name field_name in
      let context =
        Map.of_alist_exn
          [
            (obj_name, Object (Map.of_alist_exn [ (field_name, Number value) ]));
          ]
      in
      let actual = run ~template ~context in
      let expected = Ok (string_of_float value) in
      [%test_eq: (string, error) result] actual expected)
