open Core

let ( $ ) = Soup.( $ )

open Site

type site_generator = { content_path : Filename.t }

let make ~content_path = { content_path }

let generate_html_from_markdown ~markdown_str =
  let markdown = Omd.of_string markdown_str in
  Omd.to_html markdown

let instantiate_template_for_index_page (template : Site.page)
    (content : Site.page) =
  Soup.replace (template $ "#page-content") content

let generate_index_page (content_path : Filename.t) =
  let index_content_path =
    Filename.concat content_path (Filename.of_parts [ "pages"; "index.md" ])
  in
  let index_content_page =
    generate_html_from_markdown
      ~markdown_str:(index_content_path |> In_channel.read_all)
    |> Soup.parse
  in
  let index_page_path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "index.html" ])
  in
  let index_page = index_page_path |> Core.In_channel.read_all |> Soup.parse in
  instantiate_template_for_index_page index_page index_content_page;
  index_page

let generate site_generator =
  { index_page = generate_index_page site_generator.content_path }
