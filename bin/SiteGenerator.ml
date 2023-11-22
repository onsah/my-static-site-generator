open Core

let ( $ ) = Soup.( $ )

open Site

let generate_html_from_markdown ~input_file_path =
  let file_str = In_channel.read_all input_file_path in
  let markdown = Omd.of_string file_str in
  Omd.to_html markdown

let instantiate_template_for_index_page (template : Site.page)
    (content : Site.page) =
  Soup.replace (template $ "#page-content") content

let index_page_template_path =
  Filename.concat Environment.project_root
    (Filename.of_parts [ "content"; "templates"; "template.html" ])

let generate_index_page () =
  let index_page_path = Filename.of_parts [ "content"; "pages"; "index.md" ] in
  let index_page_abs_path =
    Filename.concat Environment.project_root index_page_path
  in
  let index_page_content =
    generate_html_from_markdown ~input_file_path:index_page_abs_path
    |> Soup.parse
  in
  let index_page =
    index_page_template_path |> Core.In_channel.read_all |> Soup.parse
  in
  instantiate_template_for_index_page index_page index_page_content;
  index_page

let generate () = { index_page = generate_index_page () }
