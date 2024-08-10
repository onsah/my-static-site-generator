open Core

let sprintf = Printf.sprintf

let create_directory_if_not_exists (path : Site.Path.t) =
  let path_str = Site.Path.to_string path in
  match DiskIO.get_type path with
  | Unknown ->
      print_endline
        (sprintf "Out directory %s does not exist. Creating..." path_str);
      DiskIO.create_dir path
  | File ->
      print_endline
        (sprintf "Out directory %s already exists but it's not a folder."
           path_str);
      exit 1
  | Directory -> ()

let write_file (file : Site.output_file) ~(out : Site.Path.t) =
  let module Path = Site.Path in
  printf "file path: %s\n" (Path.to_string file.path);
  let file_absolute_path = Path.join out file.path in
  List.iter (Path.parents file_absolute_path) ~f:create_directory_if_not_exists;
  DiskIO.write_all file_absolute_path ~content:file.content

let create ~(site : Site.t) ~at =
  printf "out: %s\n" (Site.Path.to_string at);
  create_directory_if_not_exists at;
  List.iter site.output_files ~f:(write_file ~out:at);
  ()
