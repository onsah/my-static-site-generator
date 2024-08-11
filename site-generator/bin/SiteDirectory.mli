(** 
    Creates the static site directory at the location `at`.
*)

open! Core

val create : site:Site.t -> at:Site.Path.t -> unit
