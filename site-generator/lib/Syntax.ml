open! Core
module Sequence = MySequence

type variable =
  | Id of string
  | Field of {
      id : string;
      field : variable;
    }
[@@deriving sexp_of]

and node =
  | Text of string
  | Variable of variable
  | For of {
      variable : variable;
      collection : variable;
      body : node List.t;
    }
[@@deriving sexp, compare]

let variable_of_list path =
  match List.rev path with
  | [] -> failwith "Illegal Argument: empty path"
  | [ id ] -> Id id
  | id :: ids ->
      List.fold ids ~init:(Id id) ~f:(fun acc id -> Field { id; field = acc })
