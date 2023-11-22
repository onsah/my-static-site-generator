
let sprintf = Printf.sprintf;;

let generate_html_from_markdown ~input_file_path =
  let file_str = Soup.read_file input_file_path in
  let markdown = Omd.of_string file_str in
  Omd.to_html markdown

let generate_index_page current_dir =
  let index_path = sprintf "%s/content/pages/index.md" current_dir in
  let index_html = (generate_html_from_markdown ~input_file_path:index_path) |> Soup.parse in
  Templatizer.generate_index_page ~content:index_html

let () = 
  let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"  in
  (* Generate index page *)
  let index_page = generate_index_page current_dir in
  (* Generate index page *)
  SiteBuilder.create_directory ~out_dir:"dist" ~index_page:index_page
