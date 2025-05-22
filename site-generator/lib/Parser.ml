open! Core
module Sequence = MySequence

type error =
  [ `ParserUnexpected of Tokenizer.token
  | `ParserFinishedUnexpectedly of Location.t
  ]
[@@deriving sexp, compare]

let rec iter (tokens : Tokenizer.token Sequence.t)
    ({ yield; abort } : (Syntax.node, error) Sequence.fallible_iter_args) : unit
    =
  let rec default tokens ~level =
    match Sequence.next tokens with
    | Some ((Tokenizer.{ kind; _ } as token), tokens) -> (
        match kind with
        | LeftCurly ->
            templating tokens ~prev_location:token.end_location
              ~level:(level + 1)
        | Text s ->
            yield Syntax.(Text s);
            default tokens ~level
        | Dot ->
            yield Syntax.(Text ".");
            default tokens ~level
        | Space ->
            yield Syntax.(Text " ");
            default tokens ~level
        | LeftParen ->
            yield Syntax.(Text "(");
            default tokens ~level
        | RightParen ->
            yield Syntax.(Text ")");
            default tokens ~level
        | Semicolon ->
            yield Syntax.(Text ";");
            default tokens ~level
        | Newline ->
            yield Syntax.(Text "\n");
            default tokens ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> ()
  and templating tokens ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | Text text -> variable [ text ] token tokens ~level
        | Foreach -> foreach_var tokens ~prev_location:token.end_location ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and variable acc last_token tokens ~level =
    let open Tokenizer in
    match Sequence.next tokens with
    | Some ({ kind = Dot; _ }, tokens) -> (
        match Sequence.next tokens with
        | Some (({ kind = Text text; _ } as token), tokens) ->
            variable (List.append acc [ text ]) token tokens ~level
        | Some (token, _) -> abort (`ParserUnexpected token)
        | None -> abort (`ParserFinishedUnexpectedly last_token.end_location))
    | Some _ ->
        yield Syntax.(Variable (variable_of_list acc));
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
  and foreach_var tokens ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | Text id ->
            foreach_in tokens ~prev_location:token.end_location
              ~variable:(Syntax.Id id) ~level
        | Space -> foreach_var tokens ~prev_location ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_in tokens ~prev_location ~variable ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | In ->
            foreach_collection tokens ~variable
              ~prev_location:token.end_location ~level
        | Space -> foreach_in tokens ~prev_location ~variable ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_collection tokens ~variable ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | Text collection_name ->
            let collection = Syntax.Id collection_name in
            foreach_enter tokens ~variable ~collection ~body:[]
              ~prev_location:token.end_location ~level
        | Space -> foreach_collection tokens ~variable ~prev_location ~level
        | _ -> abort (`ParserUnexpected token))
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  and foreach_enter tokens ~variable ~collection ~body ~prev_location ~level =
    match Sequence.next tokens with
    | Some (token, tokens) -> (
        match token.kind with
        | End -> (
            let body_parse_result =
              Sequence.of_fallible_iterator (iter (body |> Sequence.of_list))
            in
            match body_parse_result with
            | Ok body ->
                yield
                  Syntax.(
                    For
                      { variable; collection; body = body |> Sequence.to_list });
                right_curly tokens ~prev_location:token.end_location ~level
            | Error error -> abort error)
        | _ ->
            foreach_enter tokens ~variable ~collection
              ~body:(List.append body [ token ])
              ~prev_location:token.end_location ~level)
    | None -> abort (`ParserFinishedUnexpectedly prev_location)
  in
  default tokens ~level:0

let parse (tokens : Tokenizer.token Sequence.t) =
  Sequence.of_fallible_iterator (iter tokens)

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
      let expected = Ok Syntax.[ Variable (Id s1) ] in
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
        Ok Syntax.[ Variable (Field { id = s1; field = Id s2 }) ]
      in
      [%test_eq: (Syntax.node list, error) result] actual expected)

let%test_unit "parser_foreach" =
  Quickcheck.test ~trials:50
    (Quickcheck.Generator.both str_generator str_generator)
    ~f:(fun (collection_name, item_name) ->
      let tokens =
        sprintf "{{foreach %s in %s {{%s}} end}}" item_name collection_name
          item_name
        |> String.to_sequence |> Tokenizer.tokenize |> Result.ok
        |> Option.value_exn
      in
      let actual = parse tokens |> Result.map ~f:Sequence.to_list in
      let expected =
        Ok
          Syntax.
            [
              For
                {
                  variable = Id item_name;
                  collection = Id collection_name;
                  body = [ Text " "; Variable (Id item_name); Text " " ];
                };
            ]
      in
      [%test_eq: (Syntax.node list, error) result] actual expected)
