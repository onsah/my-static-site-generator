open! Core
open Context

type error

(** Human readable string for the error. *)
val show_error : error -> string

val error_location : error -> Location.t

(** Executes the [template] with the given [context]. Returns either the new
    document after templating, or the first encountered error. *)
val run :
  template:string ->
  context:context (* TODO: error list *) ->
  (string, error) result
