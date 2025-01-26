open! Core

(** I use the version of the map where comparator is polymorphic *)
module Map = Core.Map.Poly

(** Type of the values for template variables *)
type context_item =
  | String of string
  | Number of float

(** Mapping from template variables to their values. *)
type context = (string, context_item) Map.t

(** A position in the HTML document. *)
type location =
  { line : int
  ; column : int
  }

type error

val show_error : error -> string
val error_location : error -> location

(**
  returns either the new document after templating, or list of errors happened during templating.
*)
val run
  :  template:string
  -> context:context (* TODO: error list *)
  -> (string, error) result
