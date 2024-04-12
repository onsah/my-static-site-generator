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

(* User: read write execute, rest: only read *)
let unix_file_permissions = 0o744
let create_dir path = Core_unix.mkdir_p (Path.to_string path) ~perm:unix_file_permissions
