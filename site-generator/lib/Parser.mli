open! Core
module Sequence = MySequence

type error

val parse : Tokenizer.token Sequence.t -> (Syntax.node Sequence.t, error) result
