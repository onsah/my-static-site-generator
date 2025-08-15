open! Core
open Context

type error

val show_error : error -> string
val error_location : error -> Location.t

(** returns either the new document after templating, or list of errors happened
    during templating. *)
val run :
  template:string ->
  context:context (* TODO: error list *) ->
  (string, error) result
