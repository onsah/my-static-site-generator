type 'a generator = unit -> 'a option
type 'a iterator = ('a -> unit) -> unit

let of_iterator (type a) (iter : a iterator) : a generator =
  let open Effect in
  let open Effect.Deep in
  let open struct
    type _ Effect.t += Yield : a -> unit Effect.t
  end in
  let yield x = perform (Yield x) in
  let rec step =
    ref (fun () ->
        match iter yield with
        | () -> None
        | effect Yield x, k ->
            (step := fun () -> continue k ());
            Some x)
  in
  fun () -> !step ()

type ('a, 'b) fallible_iter_args = {
  yield : 'a -> unit;
  abort : 'c. 'b -> 'c;
}

type ('a, 'b) fallibe_iterator = ('a, 'b) fallible_iter_args -> unit

type ('a, 'b) step =
  | Next of 'a
  | Error of 'b
  | Done

type ('a, 'b) fallible_generator = unit -> ('a, 'b) step

let of_fallible_iterator (type a b) (iter : (a, b) fallibe_iterator) :
    (a, b) fallible_generator =
  let open Effect in
  let open Effect.Deep in
  let open struct
    type _ Effect.t += Yield : a -> unit Effect.t

    exception Abort of b
  end in
  let yield x = perform (Yield x) in
  let abort x = raise (Abort x) in
  let rec step =
    ref (fun () ->
        match iter { yield; abort } with
        | () -> Done
        | effect Yield x, k ->
            (step := fun () -> continue k ());
            Next x
        | exception Abort b ->
            (step := fun () -> Done);
            Error b)
  in
  fun () -> !step ()
