(** I use the version of the map where comparator is polymorphic *)
module Map = Core.Map.Poly

(** Type of the values for template variables *)
type context_item =
  | String of string
  | Number of float
  | Collection of context_item list
  | Object of (string, context_item) Map.t
[@@deriving sexp]

(** Mapping from template variables to their values. *)
type context = (string, context_item) Map.t [@@deriving sexp]

type context_item_type =
  | String_t
  | Number_t
  | Collection_t
  | Object_t
[@@deriving sexp, compare]

val show_item_type : context_item_type -> string
