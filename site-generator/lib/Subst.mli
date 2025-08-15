open! Core
open Context
module Sequence = MySequence

(** I use the version of the map where comparator is polymorphic *)
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
  | `TemplatingVariableNotFound of string * Location.t
  ]
[@@deriving sexp, compare]

val show_error : error -> string

val subst :
  Syntax.node Sequence.t -> context:context -> (string, [> error ]) result
