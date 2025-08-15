open Core

let of_date (date : Date.t) : string =
  let day = Date.day date |> Int.to_string in
  let month = Date.month date |> Month.to_string in
  let year = Date.year date |> Int.to_string in
  Printf.sprintf "%s %s %s" day month year
