let sprintf = Printf.sprintf;;

let ($) = Soup.($);;


let generate_html_from_markdown ~input_file_path =
  let file_str = Soup.read_file input_file_path in
  let markdown = Omd.of_string file_str in
  Omd.to_html markdown

let generate_index_page current_dir =
  let index_path = sprintf "%s/content/pages/index.md" current_dir in
  let index_html = (generate_html_from_markdown ~input_file_path:index_path) |> Soup.parse in
  let template_html = (sprintf "%s/content/templates/template.html" current_dir) 
    |> Soup.read_file
    |> Soup.parse in
  Soup.replace (template_html $ "#page-content") index_html;
  template_html

(* Generate the static site directory *)
let build_directory ~out_dir ~(index_page : Soup.soup Soup.node) = 
  if (not (Sys.file_exists out_dir)) || (not (Sys.is_directory out_dir)); then
    print_endline (sprintf "Out directory %s does not exit. Creating..." out_dir);
    Core_unix.mkdir_p ~perm:0o777 out_dir;
    
  Soup.write_file (sprintf "%s/index.html" out_dir) (Soup.to_string index_page);
  prerr_endline (sprintf "Site generated at: '%s'" out_dir)

let () = 
  let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"  in
  (* Generate index page *)
  let index_page = generate_index_page current_dir in
  (* Generate index page *)
  build_directory ~out_dir:"dist" ~index_page:index_page
