open! Core

type t = {
  line : int;
  column : int;
}
[@@deriving sexp, compare]

let make ~line ~column = { line; column }
let add_col loc ~amount = { loc with column = loc.column + amount }
let increment_col = add_col ~amount:1
let increment_line loc = { loc with line = loc.line + 1 }
let show { line; column } = sprintf "at line %i, column %i" line column
