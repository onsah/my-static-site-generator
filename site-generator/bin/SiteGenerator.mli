(** Generates files for the website. Doesn't perform any side effect. *)

open! Core

val generate : content_path:Site.Path.t -> Site.t
