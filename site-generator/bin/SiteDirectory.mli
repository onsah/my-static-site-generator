open! Core
(** 
    Module for creating the static site directory    
*)

val create : site:Site.t2 -> at:Site.Path.t -> unit
