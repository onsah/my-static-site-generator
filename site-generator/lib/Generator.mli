(** A generator is a function which generates values lazily upon being called *)
type 'a generator = unit -> 'a option

type 'a iterator = ('a -> unit) -> unit

val of_iterator : 'a iterator -> 'a generator

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

val of_fallible_iterator :
  ('a, 'b) fallibe_iterator -> ('a, 'b) fallible_generator
