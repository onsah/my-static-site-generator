open Core
(** 
    Module for creating the static site directory    
*)

type site_directory

val make : out_path:Filename.t -> site_directory
val create : site_directory -> site:Site.t -> unit
