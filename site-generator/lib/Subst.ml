open! Core
open Context
module Sequence = MySequence
module Map = Core.Map.Poly

type type_error_info = {
  typ : context_item_type;
  location : Location.t;
}
[@@deriving sexp, compare]

type error =
  [ `TemplatingUnexpectedType of type_error_info
  | `TemplatingExpectedType of type_error_info
  | `TemplatingVariableNotFound of string * Location.t
  ]
[@@deriving sexp, compare]

let show_error (error : error) =
  match error with
  | `TemplatingUnexpectedType { typ; location } ->
      sprintf "Unexpected type %s at %s"
        (Context.show_item_type typ)
        (Location.show location)
  | `TemplatingExpectedType { typ; location } ->
      sprintf "Expected type %s at %s"
        (Context.show_item_type typ)
        (Location.show location)
  | `TemplatingVariableNotFound (var, location) ->
      sprintf "Variable '%s' not found at %s" var (Location.show location)

(* FIXME: Consider returning sequence internally, and only fold at the top level *)
let rec subst (nodes : Syntax.node Sequence.t) ~(context : context) :
    (string, [> error ]) result =
  (subst_impl nodes ~context_stack:(NonEmptyStack.make context)
    : (string, error) result
    :> (string, [> error ]) result)

and subst_impl (nodes : Syntax.node Sequence.t)
    ~(context_stack : context NonEmptyStack.t) : (string, error) result =
  let open Result in
  let open Result.Let_syntax in
  nodes
  |> Sequence.fold_m ~bind ~return ~init:"" ~f:(fun acc node ->
         let%map subst_result = subst_node node ~context_stack in
         acc ^ subst_result)

and subst_node (node : Syntax.node) ~(context_stack : context NonEmptyStack.t) :
    (string, error) result =
  match node.kind with
  | Syntax.Text text -> Ok text
  | Syntax.Variable var ->
      subst_var var context_stack (Location.make ~line:(-1) ~column:(-1))
  | Syntax.For { variable; collection = collection_name; body } ->
      let open Result.Let_syntax in
      let collection =
        NonEmptyStack.find_map context_stack ~f:(fun context ->
            Map.find context collection_name)
      in
      let%bind collection =
        match collection with
        | Some items -> Ok items
        | None ->
            Error
              (`TemplatingVariableNotFound (collection_name, node.start_location))
      in
      let%bind items =
        match collection with
        | Collection items -> Ok items
        | _ ->
            Error
              (`TemplatingExpectedType
                 { typ = Collection_t; location = node.start_location })
      in
      items
      |> List.fold_result ~init:"" ~f:(fun acc item ->
             let context_stack =
               NonEmptyStack.push context_stack
                 (Map.of_alist_exn [ (variable, item) ])
             in
             let%map body = subst_impl (Sequence.of_list body) ~context_stack in
             acc ^ body)

and subst_var (var : Syntax.variable) (context_stack : context NonEmptyStack.t)
    (location : Location.t) =
  let rec prop_access obj (field : Syntax.variable) =
    match field with
    | Syntax.Id id -> (
        match Map.find obj id with
        | Some (String s) -> Ok s
        | Some (Number n) -> Ok (string_of_float n)
        | Some (Collection _) ->
            Error (`TemplatingUnexpectedType { typ = Collection_t; location })
        | Some (Object _) ->
            Error (`TemplatingUnexpectedType { typ = Object_t; location })
        | None -> Error (`TemplatingVariableNotFound (id, location)))
    | Syntax.Field { id; field } -> (
        match Map.find obj id with
        | Some (Object obj) -> prop_access obj field
        | Some (String _) ->
            Error (`TemplatingUnexpectedType { typ = String_t; location })
        | Some (Number _) ->
            Error (`TemplatingUnexpectedType { typ = String_t; location })
        | Some (Collection _) ->
            Error (`TemplatingUnexpectedType { typ = Collection_t; location })
        | None -> Error (`TemplatingVariableNotFound (id, location)))
  in
  match var with
  | Syntax.Id id -> (
      match
        NonEmptyStack.find_map context_stack ~f:(fun context ->
            Map.find context id)
      with
      | None -> Error (`TemplatingVariableNotFound (id, location))
      | Some value -> (
          match value with
          | String s -> Ok s
          | Number n -> Ok (string_of_float n)
          | Collection _ ->
              Error (`TemplatingUnexpectedType { typ = Collection_t; location })
          | Object _ ->
              Error (`TemplatingUnexpectedType { typ = Object_t; location })))
  | Syntax.Field { id; field } -> (
      match
        NonEmptyStack.find_map context_stack ~f:(fun context ->
            Map.find context id)
      with
      | None -> Error (`TemplatingVariableNotFound (id, location))
      | Some value -> (
          match value with
          | String _ ->
              Error (`TemplatingUnexpectedType { typ = String_t; location })
          | Number _ ->
              Error (`TemplatingUnexpectedType { typ = String_t; location })
          | Collection _ ->
              Error (`TemplatingUnexpectedType { typ = Collection_t; location })
          | Object obj -> prop_access obj field))
