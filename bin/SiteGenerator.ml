open Core
open Site

let generate_html_from_markdown ~input_file_path =
  let file_str = In_channel.read_all input_file_path in
  let markdown = Omd.of_string file_str in
  Omd.to_html markdown

let generate_index_page () =
  let index_page_path = Filename.of_parts [ "content"; "pages"; "index.md" ] in
  let index_page_abs_path =
    Filename.concat Environment.project_root index_page_path
  in
  let index_html =
    generate_html_from_markdown ~input_file_path:index_page_abs_path
    |> Soup.parse
  in
  Template.apply_for_index_page ~content:index_html

let generate () = { index_page = generate_index_page () }
