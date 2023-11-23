(** 
    Module for creating the static site directory    
*)

type site_directory

val make : Environment.environment -> out_dir:string -> site_directory
val create : site_directory -> index_page:Site.page -> unit
