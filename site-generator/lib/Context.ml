open Core
module Map = Core.Map.Poly

type context_item =
  | String of string
  | Number of float
  | Collection of context_item list
  | Object of (string, context_item) Map.t
[@@deriving sexp]

type context = (string, context_item) Map.t [@@deriving sexp]

type context_item_type =
  | String_t
  | Number_t
  | Collection_t
  | Object_t
[@@deriving sexp, compare]

let show_item_type : context_item_type -> string = function
  | Collection_t -> "Collection"
  | Object_t -> "Object"
  | String_t -> "String"
  | Number_t -> "Number"
