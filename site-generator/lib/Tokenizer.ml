open! Core
module Sequence = MySequence

type kind =
  | Text of string
  | LeftCurly
  | RightCurly
  | Foreach
  | In
  | End
  | Dot
  | Space
  | Newline
  | LeftParen
  | RightParen
  | Semicolon
[@@deriving sexp, compare]

let show_kind : kind -> string = function
  | Text text -> sprintf "\"%s\"" text
  | LeftCurly -> "{{"
  | RightCurly -> "}}"
  | Foreach -> "foreach"
  | In -> "in"
  | End -> "end"
  | Dot -> "."
  | Space -> " "
  | Newline -> "\n"
  | LeftParen -> "("
  | RightParen -> ")"
  | Semicolon -> ";"

type token = {
  kind : kind;
  start_location : Location.t;
  end_location : Location.t;
}
[@@deriving sexp, compare]

let end_location kind start_location =
  let amount =
    match kind with
    | LeftCurly | RightCurly -> 2
    | Foreach -> 7
    | In -> 2
    | End -> 3
    | Text text -> String.length text
    | Dot -> 1
    | Space -> 1
    | Newline -> 1
    | LeftParen -> 1
    | RightParen -> 1
    | Semicolon -> 1
  in
  Location.add_col start_location ~amount

let make_token kind start_location =
  let end_location = end_location kind start_location in
  { kind; start_location; end_location }

type error =
  [ `TokenizerExpectedOneOf of char list * Location.t
  | `TokenizerUnexpected of char * Location.t
  ]
[@@deriving sexp, compare]

let show_error = function
  | `TokenizerExpectedOneOf (chars, loc) ->
      sprintf "Tokenizer error: Expecting one of '%s' %s"
        (chars |> List.map ~f:String.of_char |> String.concat ~sep:", ")
        (loc |> Location.show)
  | `TokenizerUnexpected (char, loc) ->
      sprintf "Tokenizer error: Unexpected character '%c' %s" char
        (loc |> Location.show)

let with_location chars : (char * Location.t) Sequence.t =
  Sequence.folding_map chars ~init:(Location.make ~line:0 ~column:0)
    ~f:(fun loc char ->
      let next_loc =
        match char with
        | '\n' -> Location.increment_line loc
        | _ -> Location.increment_col loc
      in
      (next_loc, (char, loc)))

let iter (chars : char Sequence.t)
    ({ yield; abort } : (token, error) Sequence.fallible_iter_args) : unit =
  let rec default chars =
    match Sequence.next chars with
    | Some (((char, start_location) as char_loc), chars) -> (
        match char with
        | '{' -> left_curly chars ~start_location
        | '}' -> right_curly chars ~start_location
        | ' ' ->
            yield (make_token Space start_location);
            default chars
        | '\n' ->
            yield (make_token Newline start_location);
            default chars
        | '(' ->
            yield (make_token LeftParen start_location);
            default chars
        | ')' ->
            yield (make_token RightParen start_location);
            default chars
        | ';' ->
            yield (make_token Semicolon start_location);
            default chars
        | 'a' .. 'z'
        | 'A' .. 'Z'
        | '<' | '>' | '/' | '=' | '"' | '\'' | '-' | ',' | '.' ->
            text chars (String.of_char char) ~start_location
        | _ -> abort (`TokenizerUnexpected char_loc))
    | None -> ()
  and left_curly chars ~start_location =
    match Sequence.next chars with
    | Some (('{', _), chars) ->
        yield (make_token LeftCurly start_location);
        default chars
    | Some (c, _) -> abort (`TokenizerUnexpected c)
    | None ->
        abort
          (`TokenizerExpectedOneOf
             ([ '{' ], Location.increment_col start_location))
  and right_curly chars ~start_location =
    match Sequence.next chars with
    | Some (('}', _), chars) ->
        yield (make_token RightCurly start_location);
        default chars
    | Some (c, _) -> abort (`TokenizerUnexpected c)
    | None ->
        abort
          (`TokenizerExpectedOneOf
             ([ '}' ], Location.increment_col start_location))
  and text chars acc ~start_location =
    let kind_from_text text =
      match text with
      | "foreach" -> Foreach
      | "in" -> In
      | "end" -> End
      | _ -> Text text
    in
    match Sequence.next chars with
    | None ->
        yield (make_token (kind_from_text acc) start_location);
        ()
    | Some (((char, _) as char_with_loc), chars) -> (
        match char with
        | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '<' | '>' | '/' ->
            text chars (acc ^ String.of_char char) ~start_location
        | '.' ->
            let text_token = make_token (kind_from_text acc) start_location in
            let dot_token = make_token Dot text_token.end_location in
            yield text_token;
            yield dot_token;
            text chars "" ~start_location:dot_token.end_location
        | _ ->
            yield (make_token (kind_from_text acc) start_location);
            default (Sequence.shift_right chars char_with_loc))
  in
  chars |> with_location |> default

let tokenize (chars : char Sequence.t) : (token Sequence.t, [> error ]) result =
  (Sequence.of_fallible_iterator (iter chars)
    : (token Sequence.t, error) result
    :> (token Sequence.t, [> error ]) result)

let%test_unit "tokenizer_basic" =
  let string = "{{foo}}" in
  let result =
    string |> String.to_sequence |> tokenize |> Result.map ~f:Sequence.to_list
  in
  [%test_eq: (token list, error) result] result
    (Ok
       [
         make_token LeftCurly (Location.make ~line:0 ~column:0);
         make_token (Text "foo") (Location.make ~line:0 ~column:2);
         make_token RightCurly (Location.make ~line:0 ~column:5);
       ])

let%test_unit "tokenizer_left_angle" =
  let string = "<{{foo}}" in
  let result =
    string |> String.to_sequence |> tokenize |> Result.map ~f:Sequence.to_list
  in
  [%test_eq: (token list, error) result] result
    (Ok
       [
         make_token (Text "<") (Location.make ~line:0 ~column:0);
         make_token LeftCurly (Location.make ~line:0 ~column:1);
         make_token (Text "foo") (Location.make ~line:0 ~column:3);
         make_token RightCurly (Location.make ~line:0 ~column:6);
       ])

let%test_unit "tokenizer_dot" =
  let string = "foo.bar" in
  [%test_eq: (token list, error) result]
    (string |> String.to_sequence |> tokenize |> Result.map ~f:Sequence.to_list)
    (Ok
       [
         make_token (Text "foo") (Location.make ~line:0 ~column:0);
         make_token Dot (Location.make ~line:0 ~column:3);
         make_token (Text "bar") (Location.make ~line:0 ~column:4);
       ])
