open Core

type 'a t =
  | One of 'a
  | Cons of ('a * 'a t)

let top = function
  | One x -> x
  | Cons (x, _) -> x

let make x = One x
let push stack x = Cons (x, stack)

let pop = function
  | One x -> (x, None)
  | Cons (x, xs) -> (x, Some xs)

let rec find_map stack ~f =
  let open Option.Let_syntax in
  let x, xs = pop stack in
  match f x with
  | None ->
      let%bind xs = xs in
      find_map xs ~f
  | Some a -> Some a
