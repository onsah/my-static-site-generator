open Core

let generate_html_from_markdown ~input_file_path ~output_file_path =
  let file_str = In_channel.read_all input_file_path in
  let markdown = Omd.of_string file_str in
  Out_channel.write_all output_file_path ~data:(Omd.to_html markdown)

let () = 
  let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"  in
  let index_path = Printf.sprintf "%s/content/pages/index.md" current_dir in
  generate_html_from_markdown ~input_file_path:index_path ~output_file_path:"index.html"
