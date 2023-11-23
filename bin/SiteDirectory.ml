open Core

let sprintf = Printf.sprintf

type site_directory = { out_path : Filename.t }

let make ~out_path = { out_path }

let create site_directory ~index_page =
  let out_path = site_directory.out_path in
  (match (Sys_unix.file_exists out_path, Sys_unix.is_directory out_path) with
  | `No, _ ->
      print_endline
        (sprintf "Out directory %s does not exit. Creating..." out_path);
      Core_unix.mkdir_p ~perm:0o777 out_path
  | _, `No ->
      print_endline
        (sprintf "Out directory %s already exists and it's not a folder."
           out_path);
      exit 1
  | _ -> ());
  Soup.write_file (sprintf "%s/index.html" out_path) (Soup.to_string index_page);
  prerr_endline (sprintf "Site generated at: '%s'" out_path)
