open Core
include Sequence

type 'a iterator = ('a -> unit) -> unit

let of_iterator (type a) (iter : a iterator) : a t =
  let open Effect in
  let open Effect.Deep in
  let open struct
    type _ Effect.t += Yield : a -> unit Effect.t
  end in
  let yield x = perform (Yield x) in
  match iter yield with
  | _ -> empty
  | effect Yield x, k -> append (return x) (continue k ())

type ('a, 'b) fallible_iter_args = {
  yield : 'a -> unit;
  abort : 'c. 'b -> 'c;
}

type ('a, 'b) fallibe_iterator = ('a, 'b) fallible_iter_args -> unit

let of_fallible_iterator (type a b) (iter : (a, b) fallibe_iterator) :
    (a t, b) result =
  let open Effect in
  let open Effect.Deep in
  let open struct
    type _ Effect.t += Yield : a -> unit Effect.t

    exception Abort of b
  end in
  let yield x = perform (Yield x) in
  let abort x = raise (Abort x) in
  match iter { yield; abort } with
  | _ -> Ok empty
  | effect Yield x, k ->
      let open Core.Result.Let_syntax in
      let%map rest = continue k () in
      append (Sequence.return x) rest
  | exception Abort error -> Error error
