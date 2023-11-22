
let sprintf = Printf.sprintf

let create_directory ~out_dir ~index_page =
  if (not (Sys.file_exists out_dir)) || (not (Sys.is_directory out_dir)); then
    print_endline (sprintf "Out directory %s does not exit. Creating..." out_dir);
    Core_unix.mkdir_p ~perm:0o777 out_dir;
    
  Soup.write_file (sprintf "%s/index.html" out_dir) (Soup.to_string index_page);
  prerr_endline (sprintf "Site generated at: '%s'" out_dir)