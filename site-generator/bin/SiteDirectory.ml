open Core

let sprintf = Printf.sprintf

type site_directory = { out_path : Filename.t }

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
