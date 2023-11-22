open Core

let sprintf = Printf.sprintf

let create_directory ~out_dir ~index_page =
  match (Sys_unix.file_exists out_dir, Sys_unix.is_directory out_dir) with
  | `No, _ ->
      print_endline
        (sprintf "Out directory %s does not exit. Creating..." out_dir);
      Core_unix.mkdir_p ~perm:0o777 out_dir
  | _, `No ->
      print_endline
        (sprintf "Out directory %s already exists and it's not a folder."
           out_dir);
      exit 1
  | _ ->
      ();

      Soup.write_file
        (sprintf "%s/index.html" out_dir)
        (Soup.to_string index_page);
      prerr_endline (sprintf "Site generated at: '%s'" out_dir)
