open Core

type page = Soup.soup Soup.node

module Path : sig
  type t

  val from : string -> t
  val from_parts : string list -> t
  val parents : t -> t list
  val join : t -> t -> t
  val to_string : t -> string
end = struct
  type t =
    { parts : string list
    ; is_relative : bool
    }

  let separator = '/'

  let from path =
    let parts =
      String.split_on_chars path ~on:[ '/' ]
      |> List.filter ~f:(Fun.negate String.is_empty)
    in
    { parts; is_relative = not (Char.equal (String.get path 0) separator) }
  ;;

  let from_parts parts =
    List.iter parts ~f:(fun path ->
      if String.contains path separator then failwith "Unexpected separator in file part");
    { is_relative = true; parts }
  ;;

  let join path1 path2 =
    if not path2.is_relative then failwith "Expected second path to be relative";
    { parts = List.concat [ path1.parts; path2.parts ]; is_relative = path1.is_relative }
  ;;

  let to_string path =
    let parts_str = String.concat path.parts ~sep:"/" in
    match path.is_relative with
    | true -> parts_str
    | false -> String.of_char separator ^ parts_str
  ;;

  let parents path =
    match path.parts with
    | [] | [ _ ] -> []
    | parts ->
      let rest_parts_except_last =
        List.sub parts ~pos:0 ~len:(List.length path.parts - 1)
      in
      let result, _ =
        List.fold
          ~init:([], [])
          ~f:(fun (result, acc) curr ->
            let acc = List.append acc [ curr ] in
            acc :: result, acc)
          rest_parts_except_last
      in
      List.map result ~f:(fun parts -> { parts; is_relative = path.is_relative })
      |> List.rev
  ;;
end

type output_file =
  { path : Path.t (** Relative to the out directory *)
  ; content : string
  }

type post =
  { title : string
  ; created_at : Date.t
  ; (* path of the post in the website hiearachy *)
    path : string
  ; path2 : Path.t
  ; page : page
  }

type t = { output_files : output_file list }
