(** Generates the HTML files for the given content *)

open Core

type site_generator

val make : content_path:Filename.t -> site_generator
val generate2 : site_generator -> Site.t2
