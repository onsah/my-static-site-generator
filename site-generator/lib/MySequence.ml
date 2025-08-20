open Core
module MyGenerator = Generator
include Sequence

let of_iterator (type a) (iter : a MyGenerator.iterator) : a t =
  let generator = MyGenerator.of_iterator iter in
  Sequence.unfold_step ~init:generator ~f:(fun generator ->
      match generator () with
      | None -> Done
      | Some value -> Yield { value; state = generator })

let of_fallible_iterator (type a b) (iter : (a, b) MyGenerator.fallibe_iterator)
    : (a, b) result t =
  let generator = MyGenerator.of_fallible_iterator iter in
  Sequence.unfold_step ~init:generator ~f:(fun generator ->
      let open MyGenerator in
      match generator () with
      | Next value -> Yield { value = Ok value; state = generator }
      | Error error -> Yield { value = Error error; state = generator }
      | Done -> Done)

let cons (a : 'a) (seq : 'a Sequence.t) : 'a Sequence.t = append (return a) seq

(** Eagerly computes the sequence until the end or until and error is found *)
let flatten_result (seq : ('a, 'b) result t) : ('a Sequence.t, 'b) result =
  seq
  |> fold_result ~init:empty ~f:(fun acc x ->
         let open Result.Let_syntax in
         let%map a = x in
         append acc (Sequence.return a))

let%test_unit "of_fallible_iterator_1" =
  let iter MyGenerator.{ yield; abort } =
    yield 1;
    yield 2;
    abort "error"
  in
  let seq = of_fallible_iterator iter in
  let i, seq = seq |> next |> Option.value_exn in
  [%test_eq: (int, string) result] i (Ok 1);
  let i, _ = seq |> next |> Option.value_exn in
  [%test_eq: (int, string) result] i (Ok 2);
  let i, seq = seq |> next |> Option.value_exn in
  [%test_eq: (int, string) result] i (Error "error");
  [%test_eq: bool] (seq |> Sequence.is_empty) true
