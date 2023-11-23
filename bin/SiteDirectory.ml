open Core

let sprintf = Printf.sprintf

type site_directory = {
  environment : Environment.environment;
  out_dir : string;
}

let make environment ~out_dir = { environment; out_dir }

let create site_directory ~index_page =
  let out_path =
    Filename.concat site_directory.environment.project_root
      site_directory.out_dir
  in
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
