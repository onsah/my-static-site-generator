open! Core

type t [@@deriving sexp, compare]

val make : line:int -> column:int -> t
val add_col : t -> amount:int -> t
val increment_col : t -> t
val show : t -> string
