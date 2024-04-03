open Core
(** 
    Module for creating the static site directory    
*)

type site_directory
type site_directory2 = { out : Site.Path.t }

val make : out_path:Filename.t -> site_directory
val create : site_directory -> site:Site.t -> unit
val create2 : site_directory2 -> site:Site.t2 -> unit
