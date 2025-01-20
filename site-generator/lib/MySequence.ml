include Core.Sequence

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
