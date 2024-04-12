open! Core
(** 
    Module for creating the static site directory    
*)

type site_directory2 = { out : Site.Path.t }

val create2 : site_directory2 -> site:Site.t2 -> unit
