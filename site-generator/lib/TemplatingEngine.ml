open! Core
module Sequence = MySequence
module Map = Core.Map.Poly

type context_item =
  | String of string
  | Number of float
  | Collection of context_item list
  | Object of (string, context_item) Map.t
[@@deriving sexp]

type context = (string, context_item) Map.t [@@deriving sexp]

module Templating = struct
  type templating_type =
    | Collection_t
    | Object_t
  [@@deriving sexp, compare]

  let show_templating_type = function
    | Collection_t -> "Collection"
    | Object_t -> "Object"

  type type_error_info = {
    typ : templating_type;
    location : Location.t;
  }
  [@@deriving sexp, compare]

  type error =
    [ `TemplatingUnexpected of Tokenizer.kind * Location.t
    | `TemplatingVariableNotFound of string * Location.t
    | `TemplatingFinishedUnexpectedly of Location.t
    | `TemplatingExpectedType of type_error_info
    | `TemplatingUnexpectedType of type_error_info
    ]
  [@@deriving sexp, compare]

  let show_error (error : error) =
    let prefix = "Templating Error:" in
    let message =
      match error with
      | `TemplatingFinishedUnexpectedly loc ->
          sprintf "Finished Unexpectedly %s" (loc |> Location.show)
      | `TemplatingUnexpected (kind, loc) ->
          sprintf "Unexpected token '%s' %s"
            (kind |> Tokenizer.show_kind)
            (loc |> Location.show)
      | `TemplatingExpectedType { typ; location } ->
          sprintf "Expected template variable with type %s %s"
            (typ |> show_templating_type)
            (location |> Location.show)
      | `TemplatingUnexpectedType { typ; location } ->
          sprintf "Unexpected template variable with type %s %s"
            (typ |> show_templating_type)
            (location |> Location.show)
      | `TemplatingVariableNotFound (variable, loc) ->
          sprintf "Variable %s not found %s" variable (loc |> Location.show)
    in
    sprintf "%s %s" prefix message

  let substitute (path : string list) context location =
    let rec prop_access obj path =
      match path with
      | [] -> Error (`TemplatingUnexpectedType { typ = Collection_t; location })
      | prop :: path -> (
          match Map.find obj prop with
          | Some value -> (
              match value with
              | String s -> Ok s
              | Object obj -> prop_access obj path
              | Number n -> Ok (string_of_float n)
              | Collection _ ->
                  Error
                    (`TemplatingUnexpectedType { typ = Collection_t; location })
              )
          | _ -> failwith "TODO: Error handling")
    in
    match path with
    | [] -> failwith "Bug: Empty path"
    | text :: path -> (
        let open Result.Let_syntax in
        let%bind () =
          if String.for_all text ~f:Char.is_alphanum then Ok ()
          else Error (`TemplatingUnexpected (Tokenizer.Text text, location))
        in
        match
          NonEmptyStack.find_map context ~f:(fun context ->
              Map.find context text)
        with
        | None -> Error (`TemplatingVariableNotFound (text, location))
        | Some value -> (
            match value with
            | String s ->
                assert (List.is_empty path);
                Ok s
            | Number n ->
                assert (List.is_empty path);
                Ok (string_of_float n)
            | Collection _ ->
                Error
                  (`TemplatingUnexpectedType { typ = Collection_t; location })
            | Object obj -> prop_access obj path))

  let iter (tokens : Tokenizer.token Sequence.t) (context : context)
      ({ yield; abort } : (string, error) Sequence.fallible_iter_args) : unit =
    let rec default tokens context_stack =
      match Sequence.next tokens with
      | Some ((Tokenizer.{ kind; location } as token), tokens) -> (
          match kind with
          | LeftCurly ->
              templating tokens context_stack
                ~prev_location:(Tokenizer.end_location token)
          | Text s ->
              yield s;
              default tokens context_stack
          | Dot ->
              yield ".";
              default tokens context_stack
          | End ->
              exit_scope tokens context_stack
                ~prev_location:(Tokenizer.end_location token)
          | Space ->
              yield " ";
              default tokens context_stack
          | LeftParen ->
              yield "(";
              default tokens context_stack
          | RightParen ->
              yield ")";
              default tokens context_stack
          | Semicolon ->
              yield ";";
              default tokens context_stack
          | Newline ->
              yield "\n";
              default tokens context_stack
          | _ -> abort (`TemplatingUnexpected (kind, location)))
      | None ->
          ();
          assert (context_stack |> NonEmptyStack.pop |> snd |> Option.is_none)
    and templating tokens context_stack ~prev_location =
      let rec path acc token tokens =
        let open Tokenizer in
        match Sequence.next tokens with
        | Some ({ kind = Dot; _ }, tokens) -> (
            match Sequence.next tokens with
            | Some (({ kind = Text text; _ } as token), tokens) ->
                path (List.append acc [ text ]) token tokens
            | Some (token, _) ->
                abort (`TemplatingUnexpected (token.kind, token.location))
            | None -> abort (`TemplatingFinishedUnexpectedly token.location))
        | Some _ ->
            (match substitute acc context_stack token.location with
            | Ok result -> yield result
            | Error error -> abort error);
            right_curly tokens context_stack
              ~prev_location:(Tokenizer.end_location token)
        | None -> abort (`TemplatingFinishedUnexpectedly token.location)
      in
      match Sequence.next tokens with
      | Some (token, tokens) -> (
          match token.kind with
          | Text text -> path [ text ] token tokens
          | Foreach ->
              foreach_var tokens context_stack
                ~prev_location:(Tokenizer.end_location token)
          | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and right_curly tokens context_stack ~prev_location =
      match Sequence.next tokens with
      | Some (token, tokens) -> (
          match token.kind with
          | RightCurly -> default tokens context_stack
          | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_var tokens context_stack ~prev_location =
      match Sequence.next tokens with
      | Some (token, tokens) -> (
          match token.kind with
          | Text var_name ->
              foreach_in tokens context_stack
                ~prev_location:(Tokenizer.end_location token)
                ~var_name
          | Space -> foreach_var tokens context_stack ~prev_location
          | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_in tokens context_stack ~prev_location ~var_name =
      match Sequence.next tokens with
      | Some (token, tokens) -> (
          match token.kind with
          | In ->
              foreach_collection tokens context_stack
                ~prev_location:(Tokenizer.end_location token)
                ~var_name
          | Space -> foreach_in tokens context_stack ~prev_location ~var_name
          | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_collection tokens context_stack ~prev_location ~var_name =
      match Sequence.next tokens with
      | Some (token, tokens) -> (
          match token.kind with
          | Text collection_name ->
              foreach_enter tokens context_stack ~var_name ~collection_name
                ~collection_location:token.location
          | Space ->
              foreach_collection tokens context_stack ~prev_location ~var_name
          | _ -> abort (`TemplatingUnexpected (token.kind, token.location)))
      | None -> abort (`TemplatingFinishedUnexpectedly prev_location)
    and foreach_enter tokens context_stack ~var_name ~collection_name
        ~collection_location =
      (* Push scope *)
      let items =
        NonEmptyStack.find_map context_stack ~f:(fun context ->
            Map.find context collection_name)
      in
      let items =
        match items with
        | Some items -> items
        | None ->
            abort
              (`TemplatingVariableNotFound (collection_name, collection_location))
      in
      let items =
        match items with
        | Collection items -> items
        | _ ->
            abort
              (`TemplatingExpectedType
                 { typ = Collection_t; location = collection_location })
      in
      let foreach_tokens =
        Sequence.take_while tokens ~f:(fun token ->
            Tokenizer.(
              match token.kind with
              | End -> false
              | _ -> true))
      in
      let tokens_after =
        Sequence.drop_while tokens ~f:(fun token ->
            Tokenizer.(
              match token.kind with
              | End -> false
              | _ -> true))
      in
      let foreach_tokens =
        Sequence.append foreach_tokens (Sequence.take tokens_after 2)
      in
      (* For each item in the collection repeat *)
      items
      |> List.iter ~f:(fun item ->
             scope_enter foreach_tokens context_stack
               (Map.of_alist_exn [ (var_name, item) ]));
      default (Sequence.drop tokens_after 2) context_stack
    and scope_enter tokens context_stack new_context =
      let context_stack = NonEmptyStack.push context_stack new_context in
      default tokens context_stack
    and exit_scope tokens context_stack ~prev_location =
      match NonEmptyStack.pop context_stack with
      | _, None ->
          failwith
            "Exited top level context while still parsing, this is a bug."
      | _, Some context_stack -> right_curly tokens context_stack ~prev_location
    in
    default tokens (NonEmptyStack.make context)

  let perform ~(tokens : Tokenizer.token Sequence.t) (context : context) :
      (string Sequence.t, [> error ]) result =
    (Sequence.of_fallible_iterator (iter tokens context)
      : (string Sequence.t, error) result
      :> (string Sequence.t, [> error ]) result)

  (* TESTS *)

  let str_generator =
    let first = Quickcheck.Generator.char_alpha in
    let rest = String.gen_with_length 4 Quickcheck.Generator.char_alphanum in
    Quickcheck.Generator.map2 first rest ~f:(sprintf "%c%s")

  let floats_generator n = List.gen_with_length n Float.gen_finite

  let%test_unit "perform_templating_string_alphanum" =
    Quickcheck.test ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (s1, s2) ->
        let tokens =
          Tokenizer.(
            Sequence.of_list [ LeftCurly; Text s1; RightCurly ]
            |> Sequence.map ~f:(fun kind ->
                   { kind; location = Location.make ~line:0 ~column:0 }))
        in
        let context = Map.of_alist_exn [ (s1, String s2) ] in
        let result = perform ~tokens context in
        let actual = result |> Result.map ~f:Sequence.to_list in
        let expected = Ok [ s2 ] in
        [%test_eq: (string list, error) result] actual expected)

  let%test_unit "perform_templating_string_float" =
    Quickcheck.test ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (s1, s2) ->
        let open Tokenizer in
        let tokens =
          Sequence.of_list [ LeftCurly; Text s1; RightCurly ]
          |> Sequence.map ~f:(fun kind ->
                 { kind; location = Location.make ~line:0 ~column:0 })
        in
        let context = Map.of_alist_exn [ (s1, String s2) ] in
        let result = perform ~tokens context in
        let actual =
          result |> Result.ok |> Option.value_exn |> Sequence.to_list
        in
        let expected = [ s2 ] in
        [%test_eq: string list] actual expected)

  let%test_unit "perform_templating_foreach" =
    Quickcheck.test ~trials:50
      (Quickcheck.Generator.map3 str_generator str_generator
         (floats_generator 10) ~f:(fun x y z -> (x, y, z)))
      ~f:(fun (collection_name, item_name, items) ->
        let tokens =
          Sequence.of_list
            Tokenizer.
              [
                LeftCurly;
                Foreach;
                Text item_name;
                In;
                Text collection_name;
                LeftCurly;
                Text item_name;
                RightCurly;
                End;
                RightCurly;
              ]
          |> Sequence.map ~f:(fun kind ->
                 Tokenizer.{ kind; location = Location.make ~line:0 ~column:0 })
        in
        let context =
          Map.of_alist_exn
            [
              ( collection_name,
                Collection (items |> List.map ~f:(fun i -> Number i)) );
            ]
        in
        let result = perform ~tokens context in
        let actual =
          result |> Result.ok |> Option.value_exn |> Sequence.to_list
        in
        let expected = items |> List.map ~f:string_of_float in
        [%test_eq: string list] actual expected)

  let%test_unit "perform_templating_foreach_unexpected_type" =
    Quickcheck.test ~trials:50
      (Quickcheck.Generator.both str_generator str_generator)
      ~f:(fun (var_name, collection_name) ->
        let tokens =
          Sequence.of_list
            Tokenizer.
              [
                LeftCurly;
                Foreach;
                Text var_name;
                In;
                Text collection_name;
                End;
                RightCurly;
              ]
          |> Sequence.map ~f:(fun kind ->
                 Tokenizer.{ kind; location = Location.make ~line:0 ~column:0 })
        in
        let context = Map.of_alist_exn [ (collection_name, Number 0.) ] in
        let result = perform ~tokens context in
        let actual = result |> Result.error in
        let expected =
          Some
            (`TemplatingExpectedType
               {
                 typ = Collection_t;
                 location = Location.make ~line:0 ~column:0;
               })
        in
        [%test_eq: error option] actual expected)

  let%test_unit "perform_templating_object" =
    Quickcheck.test ~trials:50
      (Quickcheck.Generator.map3 str_generator str_generator
         Float.quickcheck_generator ~f:(fun x y z -> (x, y, z)))
      ~f:(fun (obj_name, field_name, value) ->
        let tokens =
          Sequence.of_list
            Tokenizer.
              [ LeftCurly; Text obj_name; Dot; Text field_name; RightCurly ]
          |> Sequence.map ~f:(fun kind ->
                 Tokenizer.{ kind; location = Location.make ~line:0 ~column:0 })
        in
        let context =
          Map.of_alist_exn
            [
              ( obj_name,
                Object (Map.of_alist_exn [ (field_name, Number value) ]) );
            ]
        in
        let actual =
          perform ~tokens context
          |> Result.map ~f:(fun seq -> seq |> Sequence.to_list |> String.concat)
        in
        let expected = Ok (string_of_float value) in
        [%test_eq: (string, error) result] actual expected)

  (* TODO: test object access templating *)
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
    | `TemplatingUnexpectedType _
    | `TemplatingVariableNotFound _ ) as error -> Templating.show_error error

let error_location : error -> Location.t = function
  | `TemplatingFinishedUnexpectedly loc
  | `TemplatingUnexpected (_, loc)
  | `TemplatingExpectedType { location = loc; _ }
  | `TemplatingUnexpectedType { location = loc; _ }
  | `TemplatingVariableNotFound (_, loc)
  | `TokenizerExpectedOneOf (_, loc)
  | `TokenizerUnexpected (_, loc) -> loc

let run ~(template : string) ~(context : context) =
  let open Result.Let_syntax in
  let%bind tokens = Tokenizer.tokenize (template |> String.to_sequence) in
  let%map strings = Templating.perform ~tokens context in
  strings |> Sequence.to_list |> String.concat

let%test_unit "perform_templating_error_location" =
  let template = "<html><head></head><body>{{/}}</body></html>" in
  let context = Map.empty in
  let actual = run ~template ~context in
  let expected =
    Error
      (`TemplatingUnexpected
         (Tokenizer.Text "/", Location.make ~line:0 ~column:27))
  in
  [%test_eq: (string, error) result] actual expected
