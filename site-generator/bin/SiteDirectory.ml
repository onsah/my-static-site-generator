open Core

let sprintf = Printf.sprintf

type site_directory = { out_path : Filename.t }
type site_directory2 = { out : Site.Path.t }

let make ~out_path = { out_path }

(* User: read write execute, rest: only read *)
let unix_file_permissions = 0o744

let create site_directory ~(site : Site.t) =
  let out_path = site_directory.out_path in
  (match (Sys_unix.file_exists out_path, Sys_unix.is_directory out_path) with
  | `No, _ ->
      print_endline
        (sprintf "Out directory %s does not exit. Creating..." out_path);
      Core_unix.mkdir_p ~perm:unix_file_permissions out_path
  | _, `No ->
      print_endline
        (sprintf "Out directory %s already exists and it's not a folder."
           out_path);
      exit 1
  | _ -> ());
  Out_channel.write_all
    (sprintf "%s/index.html" out_path)
    ~data:(Soup.to_string site.index_page);
  Out_channel.write_all
    (Filename.concat out_path "blog.html")
    ~data:(Soup.to_string site.blog_page);
  Core_unix.mkdir_p ~perm:unix_file_permissions
    (Filename.concat out_path "posts");
  ignore
    (List.map site.posts ~f:(fun post ->
         printf "out path: %s\n" (Filename.concat out_path post.path);
         Out_channel.write_all
           (Filename.concat out_path post.path)
           ~data:(Soup.to_string post.page);
         ()));
  prerr_endline (sprintf "Site generated at: '%s'" out_path)

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

let create2 { out } ~(site : Site.t2) =
  printf "out: %s\n" (Site.Path.to_string out);
  create_directory_if_not_exists out;
  List.iter site.output_files ~f:(write_file ~out);
  ()
