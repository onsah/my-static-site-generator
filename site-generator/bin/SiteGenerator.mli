(** Generates the HTML files for the given content *)

open! Core

val generate : content_path:Site.Path.t -> Site.t
