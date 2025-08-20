open! Core
module Sequence = MySequence

type error =
  [ `ParserUnexpected of Tokenizer.token
  | `ParserFinishedUnexpectedly of Location.t
  ]
[@@deriving sexp, compare]

let show_error (error : error) =
  match error with
  | `ParserUnexpected token ->
      sprintf "Unexpected token %s at %s"
        (Tokenizer.show_kind token.kind)
        (Location.show token.start_location)
  | `ParserFinishedUnexpectedly location ->
      sprintf "Parser finished unexpectedly at %s" (Location.show location)

let rec iter (tokens : Tokenizer.token Sequence.t)
    ({ yield; abort } : (Syntax.node, error) Generator.fallible_iter_args) :
    unit =
  let rec default tokens ~level =
    let open Tokenizer in
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | LeftCurly ->
            templating tokens ~prev_location:token.end_location
              ~level:(level + 1)
        | Text s ->
            yield
              { kind = Syntax.(Text s); start_location = token.start_location };
            default tokens ~level
        | Dot ->
            yield
              {
                kind = Syntax.(Text ".");
                start_location = token.start_location;
              };
            default tokens ~level
        | Space ->
            yield
              {
                kind = Syntax.(Text " ");
                start_location = token.start_location;
              };
            default tokens ~level
        | LeftParen ->
            yield
              {
                kind = Syntax.(Text "(");
                start_location = token.start_location;
              };
            default tokens ~level
        | RightParen ->
            yield
              {
                kind = Syntax.(Text ")");
                start_location = token.start_location;
              };
            default tokens ~level
        | Semicolon ->
            yield
              {
                kind = Syntax.(Text ";");
                start_location = token.start_location;
              };
            default tokens ~level
        | Newline ->
            yield
              {
                kind = Syntax.(Text "\n");
                start_location = token.start_location;
              };
            default tokens ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> ()
  and templating tokens ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | Text text ->
            if String.for_all text ~f:Char.is_alphanum then
              variable [ text ] token tokens ~level
                ~start_location:token.start_location
            else abort (`ParserUnexpected token)
        | Foreach ->
            foreach_var tokens ~start_location:token.start_location
              ~prev_location:token.end_location ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and variable acc last_token tokens ~level ~start_location =
    let open Tokenizer in
    match Sequence.next tokens with
    | Some ({ kind = Dot; _ }, tokens) -> (
        match Sequence.next tokens with
        | Some (({ kind = Text text; _ } as token), tokens) ->
            if String.for_all text ~f:Char.is_alphanum then
              variable (List.append acc [ text ]) token tokens ~level
                ~start_location
            else abort (`ParserUnexpected token)
        | Some (token, _) -> abort (`ParserUnexpected token)
        | None -> abort (`ParserFinishedUnexpectedly last_token.end_location))
    | Some _ ->
        yield
          { kind = Syntax.(Variable (variable_of_list acc)); start_location };
        right_curly tokens ~prev_location:last_token.end_location ~level
    | None -> abort (`ParserFinishedUnexpectedly last_token.end_location)
  and right_curly tokens ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        let open Tokenizer in
        match token.kind with
        | RightCurly ->
            assert (level > 0);
            (* TODO: nesting error *)
            default tokens ~level:(level - 1)
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_var tokens ~start_location ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | Text id ->
            foreach_in tokens ~start_location ~prev_location:token.end_location
              ~variable:id ~level
        | Space -> foreach_var tokens ~start_location ~prev_location ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_in tokens ~start_location ~prev_location ~variable ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | In ->
            foreach_collection tokens ~variable ~start_location
              ~prev_location:token.end_location ~level
        | Space ->
            foreach_in tokens ~start_location ~prev_location ~variable ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_collection tokens ~variable ~start_location ~prev_location ~level
      =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | Text collection_name ->
            foreach_enter tokens ~variable ~collection:collection_name ~body:[]
              ~start_location ~prev_location:token.end_location ~level
        | Space ->
            foreach_collection tokens ~variable ~start_location ~prev_location
              ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_enter tokens ~variable ~collection ~body ~start_location
      ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | End -> (
            let body_parse_result =
              Sequence.of_fallible_iterator (iter (body |> Sequence.of_list))
              |> Sequence.flatten_result
            in
            match body_parse_result with
            | Ok body ->
                yield
                  {
                    kind =
                      Syntax.(
                        For
                          {
                            variable;
                            collection;
                            body = body |> Sequence.to_list;
                          });
                    start_location;
                  };
                right_curly tokens ~prev_location:token.end_location ~level
            | Error error -> abort error)
        | _ ->
            foreach_enter tokens ~variable ~collection
              ~body:(List.append body [ token ])
              ~start_location ~prev_location:token.end_location ~level)
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  in
  default tokens ~level:0

let parse (tokens : Tokenizer.token Sequence.t) :
    (Syntax.node Sequence.t, [> error ]) result =
  (Sequence.of_fallible_iterator (iter tokens) |> Sequence.flatten_result
    : (Syntax.node Sequence.t, error) result
    :> (Syntax.node Sequence.t, [> error ]) result)

let str_generator =
  let first = Quickcheck.Generator.char_alpha in
  let rest = String.gen_with_length 4 Quickcheck.Generator.char_alphanum in
  Quickcheck.Generator.map2 first rest ~f:(sprintf "%c%s")

let%test_unit "parser_variable_id" =
  Quickcheck.test ~trials:50 str_generator ~f:(fun s1 ->
      let tokens =
        sprintf "{{%s}}" s1 |> String.to_sequence |> Tokenizer.tokenize
        |> Result.ok |> Option.value_exn
      in
      let actual = parse tokens |> Result.map ~f:Sequence.to_list in
      let expected =
        Ok
          Syntax.
            [
              {
                kind = Variable (Id s1);
                start_location = Location.make ~line:0 ~column:2;
              };
            ]
      in
      [%test_eq: (Syntax.node list, error) result] actual expected)

let%test_unit "parser_variable_field" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator) ~f:(fun (s1, s2) ->
      let tokens =
        sprintf "{{%s.%s}}" s1 s2 |> String.to_sequence |> Tokenizer.tokenize
        |> Result.ok |> Option.value_exn
      in
      let actual = parse tokens |> Result.map ~f:Sequence.to_list in
      let expected =
        Ok
          Syntax.
            [
              {
                kind = Variable (Field { id = s1; field = Id s2 });
                start_location = Location.make ~line:0 ~column:2;
              };
            ]
      in
      [%test_eq: (Syntax.node list, error) result] actual expected)

let%test_unit "parser_foreach" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator)
    ~f:(fun (item_name, collection_name) ->
      let tokens =
        sprintf "{{foreach %s in %s {{%s}} end}}" item_name collection_name
          item_name
        |> String.to_sequence |> Tokenizer.tokenize |> Result.ok
        |> Option.value_exn
      in
      let actual = parse tokens |> Result.map ~f:Sequence.to_list in
      let expected =
        let body_start_location =
          Location.make ~line:0
            ~column:
              (10 + String.length item_name + 4 + String.length collection_name)
        in
        let variable_start_location =
          body_start_location |> Location.add_col ~amount:3
        in
        Ok
          Syntax.
            [
              {
                kind =
                  For
                    {
                      variable = item_name;
                      collection = collection_name;
                      body =
                        [
                          {
                            kind = Text " ";
                            start_location = body_start_location;
                          };
                          {
                            kind = Variable (Id item_name);
                            start_location = variable_start_location;
                          };
                          {
                            kind = Text " ";
                            start_location =
                              variable_start_location
                              |> Location.add_col
                                   ~amount:(String.length item_name + 2);
                          };
                        ];
                    };
                start_location = Location.make ~line:0 ~column:2;
              };
            ]
      in
      [%test_eq: (Syntax.node list, error) result] actual expected)
