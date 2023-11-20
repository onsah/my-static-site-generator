

let generate_html_from_markdown ~input_file_path =
  let file_str = Core.In_channel.read_all input_file_path in
  let markdown = Omd.of_string file_str in
  Omd.to_html markdown

let build_site ~out_dir ~index_html = 
  if (not (Sys.file_exists out_dir)) || (not (Sys.is_directory out_dir)); then
    print_endline (Printf.sprintf "Out directory %s does not exit. Creating..." out_dir);
    Core_unix.mkdir_p ~perm:0o777 out_dir;
    
  Core.Out_channel.write_all (Printf.sprintf "%s/index.html" out_dir) ~data:(index_html);
  prerr_endline (Printf.sprintf "Site generated at: '%s'" out_dir)

let () = 
  let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"  in
  let index_path = Printf.sprintf "%s/content/pages/index.md" current_dir in
  let index_html = generate_html_from_markdown ~input_file_path:index_path in
  build_site ~out_dir:"dist" ~index_html:index_html
