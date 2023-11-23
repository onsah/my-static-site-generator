(** Generates the HTML files for the given content *)

type site_generator

val make : Environment.environment -> site_generator
val generate : site_generator -> Site.t
