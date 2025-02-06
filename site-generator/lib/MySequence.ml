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
  match_with
    iter
    yield
    { retc = (fun _ -> empty)
    ; effc =
        (* TODO: Use dedicated effect syntax when we have OCaml 5.3 *)
        (fun (type c) (eff : c Effect.t) ->
          match eff with
          | Yield x ->
            Some (fun (k : (c, _) continuation) -> append (return x) (continue k ()))
          | _ -> None)
    ; exnc = raise
    }
;;

type ('a, 'b) fallibe_iterator = ('a -> unit) -> ('b -> unit) -> unit

let of_fallible_iterator (type a b) (iter : (a, b) fallibe_iterator) : (a t, b) result =
  let open Effect in
  let open Effect.Deep in
  let open struct
    type _ Effect.t += Yield : a -> unit Effect.t
    type _ Effect.t += Abort : b -> unit Effect.t
  end in
  let yield x = perform (Yield x) in
  let abort x = perform (Abort x) in
  match_with
    (fun () -> iter yield abort)
    ()
    { retc = (fun _ -> Ok empty)
    ; effc =
        (* TODO: Use dedicated effect syntax when we have OCaml 5.3 *)
        (fun (type c) (eff : c Effect.t) ->
          match eff with
          | Yield x ->
            Some
              (fun (k : (c, _) continuation) ->
                let open Core.Result.Let_syntax in
                let%map rest = continue k () in
                append (Sequence.return x) rest)
          | Abort error -> Some (fun _ -> Error error)
          | _ -> None)
    ; exnc = raise
    }
;;
