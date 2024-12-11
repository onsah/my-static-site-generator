open! Core
open Site

type path_type = File | Directory | Unknown

let get_type path =
  match
    ( Sys_unix.file_exists (Path.to_string path),
      Sys_unix.is_directory (Path.to_string path) )
  with
  | `Yes, `Yes -> Directory
  | `Yes, `No -> File
  | _ -> Unknown

let write_all path ~content =
  Out_channel.write_all (Path.to_string path) ~data:content

let read_all path =
  match get_type path with
  | File -> In_channel.read_all (path |> Path.to_string)
  | Directory -> failwith "Illegal Argument: Can't read directory."
  | Unknown -> failwith (sprintf "Illegal Argument: '%s' doesn't exist." (Path.to_string path))

let list path =
  match get_type path with
  | Directory ->
      List.map
        (Sys_unix.readdir (Path.to_string path) |> List.of_array)
        ~f:Path.from
  | _ -> failwith (sprintf "Illegal Argument: '%s' is not a directory." (Path.to_string path))

(* User: read write execute, rest: only read *)
let unix_file_permissions = 0o744

let create_dir path =
  Core_unix.mkdir_p (Path.to_string path) ~perm:unix_file_permissions
