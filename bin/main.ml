open Core

let () = 
  let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"  in
  let index_path = Printf.sprintf "%s/content/pages/index.md" current_dir in
  let index_file = In_channel.read_all index_path in
  print_endline index_file
