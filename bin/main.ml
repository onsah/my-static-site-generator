open Core
open Omd

let () = 
  let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"  in
  let index_path = Printf.sprintf "%s/content/pages/index.md" current_dir in
  let index_file_str = In_channel.read_all index_path in
  let markdown = of_string index_file_str in
  Out_channel.write_all "index.html" ~data:(Omd.to_html markdown)
