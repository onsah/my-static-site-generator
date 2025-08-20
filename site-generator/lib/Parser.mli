open! Core
module Sequence = MySequence

type error =
  [ `ParserUnexpected of Tokenizer.token
  | `ParserFinishedUnexpectedly of Location.t
  ]
[@@deriving sexp, compare]

val show_error : error -> string

val parse :
  Tokenizer.token Sequence.t -> (Syntax.node List.t, [> error ]) result
