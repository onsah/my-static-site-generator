open Core
(** 
    Module for creating the static site directory    
*)

type site_directory

val make : out_path:Filename.t -> site_directory
val create : site_directory -> index_page:Site.page -> unit
