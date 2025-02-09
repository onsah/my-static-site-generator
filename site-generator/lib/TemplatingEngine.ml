open! Core
module Sequence = MySequence
module Map = Core.Map.Poly

type context_item =
  | String of string
  | Number of float
  | Collection of context_item list

type context = (string, context_item) Map.t

type location =
  { line : int
  ; column : int
  }
[@@deriving sexp, compare]

module Location = struct
  let add_col loc ~amount = { loc with column = loc.column + amount }
  let increment_col = add_col ~amount:1
  let show { line; column } = sprintf "at line %i, column %i" line column
end

module Tokenizer = struct
  type kind =
    | Text of string
    | LeftCurly
    | RightCurly
    | Foreach
    | In
    | End
  [@@deriving sexp, compare]

  let show_kind : kind -> string = function
    | Text text -> sprintf "\"%s\"" text
    | LeftCurly -> "{{"
    | RightCurly -> "}}"
    | Foreach -> "foreach"
    | In -> "in"
    | End -> "end"
  ;;

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

  let show_error = function
    | `TokenizerExpectedOneOf (chars, loc) ->
      sprintf
        "Tokenizer error: Expecting one of '%s' %s"
        (chars |> List.map ~f:String.of_char |> String.concat ~sep:", ")
        (loc |> Location.show)
    | `TokenizerUnexpected (char, loc) ->
      sprintf "Tokenizer error: Unexpected character '%c' %s" char (loc |> Location.show)
  ;;

  let end_location { kind; location } =
    let amount =
      match kind with
      | LeftCurly | RightCurly -> 2
      | Foreach -> 7
      | In -> 2
      | End -> 3
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
      let kind_from_text text =
        match text with
        | "foreach" -> Foreach
        | "in" -> In
        | "end" -> End
        | _ -> Text text
      in
      match Sequence.next chars with
      | None ->
        f { kind = kind_from_text acc; location = start_location };
        ()
      | Some (((char, _) as char_with_loc), chars) ->
        (match char with
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '<' | '>' | '/' ->
           text chars (acc ^ String.of_char char) ~start_location
         | _ ->
           f { kind = kind_from_text acc; location = start_location };
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
  type templating_type = Collection_t [@@deriving sexp, compare]

  let show_templating_type = function
    | Collection_t -> "Collection"
  ;;

  type expected_type =
    { expected : templating_type
    ; location : location
    }
  [@@deriving sexp, compare]

  type error =
    [ `TemplatingUnexpected of Tokenizer.kind * location
    | `TemplatingVariableNotFound of string * location
    | `TemplatingFinishedUnexpectedly of location
    | `TemplatingExpectedType of expected_type
    ]
  [@@deriving sexp, compare]

  let show_error error =
    let prefix = "Templating Error:" in
    let message =
      match error with
      | `TemplatingFinishedUnexpectedly loc ->
        sprintf "Finished Unexpectedly %s" (loc |> Location.show)
      | `TemplatingUnexpected (kind, loc) ->
        sprintf
          "Unexpected token %s %s"
          (kind |> Tokenizer.show_kind)
          (loc |> Location.show)
      | `TemplatingExpectedType { expected; location } ->
        sprintf
          "Expected template variable with type %s %s"
          (expected |> show_templating_type)
          (location |> Location.show)
      | `TemplatingVariableNotFound (variable, loc) ->
        sprintf "Variable %s not found %s" variable (loc |> Location.show)
    in
    sprintf "%s %s" prefix message
  ;;

  let substitute text context =
    let open Option.Let_syntax in
    let%map value =
      NonEmptyStack.find_map context ~f:(fun context -> Map.find context text)
    in
    match value with
    | String s -> s
    | Number n -> string_of_float n
    | Collection _ -> failwith "TODO: return unexpected type error"
  ;;

  let iter
        (tokens : Tokenizer.token Sequence.t)
        (context : context)
        (f : string -> unit)
        (abort : error -> unit)
    : unit
    =
    let rec default tokens context_stack =
      match Sequence.next tokens with
      | Some ((Tokenizer.{ kind; location } as token), tokens) ->
        (match kind with
         | LeftCurly ->
           templating tokens context_stack ~prev_location:(Tokenizer.end_location token)
         | Text s ->
           f s;
           default tokens context_stack
         | End ->
           exit_scope tokens context_stack ~prev_location:(Tokenizer.end_location token)
         | _ -> abort (`TemplatingUnexpected (kind, location)))
        (* TODO: check if we have only single context on the context *)
      | None -> ()
    and templating tokens context_stack ~prev_location =
      let variable text token =
        if not (String.for_all text ~f:(fun c -> Char.is_alphanum c))
        then abort (`TemplatingUnexpected Tokenizer.(token.kind, token.location));
        match substitute text context_stack with
        | Some value -> f value
        | None -> abort (`TemplatingVariableNotFound Tokenizer.(text, token.location))
      in
      match Sequence.next tokens with
      | Some (token, tokens) ->
        (match token.kind with
         | Text text ->
           variable text token;
           right_curly tokens context_stack ~prev_location:(Tokenizer.end_location token)
         | Foreach ->
           foreach_var tokens context_stack ~prev_location:(Tokenizer.end_location token)
         | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and right_curly tokens context_stack ~prev_location =
      match Sequence.next tokens with
      | Some (token, tokens) ->
        (match token.kind with
         | RightCurly -> default tokens context_stack
         | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_var tokens context_stack ~prev_location =
      match Sequence.next tokens with
      | Some (token, tokens) ->
        (match token.kind with
         | Text var_name ->
           foreach_in
             tokens
             context_stack
             ~prev_location:(Tokenizer.end_location token)
             ~var_name
         | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_in tokens context_stack ~prev_location ~var_name =
      match Sequence.next tokens with
      | Some (token, tokens) ->
        (match token.kind with
         | In ->
           foreach_collection
             tokens
             context_stack
             ~prev_location:(Tokenizer.end_location token)
             ~var_name
         | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_collection tokens context_stack ~prev_location ~var_name =
      match Sequence.next tokens with
      | Some (token, tokens) ->
        (match token.kind with
         | Text collection_name ->
           foreach_enter
             tokens
             context_stack
             ~var_name
             ~collection_name
             ~collection_location:token.location
         | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_enter tokens context_stack ~var_name ~collection_name ~collection_location
      =
      (* Push scope *)
      let items =
        NonEmptyStack.find_map context_stack ~f:(fun context ->
          Map.find context collection_name)
      in
      let items =
        match items with
        | Some items -> items
        | None ->
          abort (`TemplatingVariableNotFound (collection_name, collection_location));
          failwith "Unreachable" (* TODO: Can't make abort polymorphic *)
      in
      let items =
        match items with
        | Collection items -> items
        | _ ->
          abort
            (`TemplatingExpectedType
                { expected = Collection_t; location = collection_location });
          failwith "Unreachable" (* TODO: Can't make abort polymorphic *)
      in
      (* For each item in the collection repeat *)
      items
      |> List.iter ~f:(fun item ->
        scope_enter tokens context_stack (Map.of_alist_exn [ var_name, item ]))
    and scope_enter tokens context_stack new_context =
      let context_stack = NonEmptyStack.push context_stack new_context in
      default tokens context_stack
    and exit_scope tokens context_stack ~prev_location =
      match NonEmptyStack.pop context_stack with
      | _, None -> failwith "TODO: Exited top level context"
      | _, Some context_stack -> right_curly tokens context_stack ~prev_location
    in
    default tokens (NonEmptyStack.make context)
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

  let floats_generator n = List.gen_with_length n Float.gen_finite

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

  let%test_unit "perform_templating_foreach" =
    Quickcheck.test
      ~trials:50
      (Quickcheck.Generator.map3
         str_generator
         str_generator
         (floats_generator 10)
         ~f:(fun x y z -> x, y, z))
      ~f:(fun (collection_name, item_name, items) ->
        let tokens =
          Sequence.of_list
            Tokenizer.
              [ LeftCurly
              ; Foreach
              ; Text item_name
              ; In
              ; Text collection_name
              ; LeftCurly
              ; Text item_name
              ; RightCurly
              ; End
              ; RightCurly
              ]
          |> Sequence.map ~f:(fun kind ->
            Tokenizer.{ kind; location = { line = 0; column = 0 } })
        in
        let context =
          Map.of_alist_exn
            [ collection_name, Collection (items |> List.map ~f:(fun i -> Number i)) ]
        in
        let result = perform ~tokens context in
        let actual = result |> Result.ok |> Option.value_exn |> Sequence.to_list in
        let expected = items |> List.map ~f:string_of_float in
        [%test_eq: string list] actual expected)
  ;;

  let%test_unit "perform_templating_foreach_unexpected_type" =
    Quickcheck.test
      ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (var_name, collection_name) ->
        let tokens =
          Sequence.of_list
            Tokenizer.
              [ LeftCurly
              ; Foreach
              ; Text var_name
              ; In
              ; Text collection_name
              ; End
              ; RightCurly
              ]
          |> Sequence.map ~f:(fun kind ->
            Tokenizer.{ kind; location = { line = 0; column = 0 } })
        in
        let context = Map.of_alist_exn [ collection_name, Number 0. ] in
        let result = perform ~tokens context in
        let actual = result |> Result.error in
        let expected =
          Some
            (`TemplatingExpectedType
                { expected = Collection_t; location = { line = 0; column = 0 } })
        in
        [%test_eq: error option] actual expected)
  ;;
end

type error =
  [ Tokenizer.error
  | Templating.error
  ]
[@@deriving sexp, compare]

let show_error (error : error) =
  match error with
  | (`TokenizerExpectedOneOf _ | `TokenizerUnexpected _) as error ->
    Tokenizer.show_error error
  | ( `TemplatingFinishedUnexpectedly _
    | `TemplatingUnexpected _
    | `TemplatingExpectedType _
    | `TemplatingVariableNotFound _ ) as error -> Templating.show_error error
;;

let error_location : error -> location = function
  | `TemplatingFinishedUnexpectedly loc
  | `TemplatingUnexpected (_, loc)
  | `TemplatingExpectedType { location = loc; _ }
  | `TemplatingVariableNotFound (_, loc)
  | `TokenizerExpectedOneOf (_, loc)
  | `TokenizerUnexpected (_, loc) -> loc
;;

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
