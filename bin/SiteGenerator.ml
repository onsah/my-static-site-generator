open Core

let ( $ ) = Soup.( $ )

open Site

type site_generator = { content_path : Filename.t }

let make ~content_path = { content_path }

let generate_html_from_markdown ~markdown_str =
  let markdown = Omd.of_string markdown_str in
  Omd.to_html markdown

let get_header_component (content_path : Filename.t) =
  let path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "header.html" ])
  in
  path |> In_channel.read_all |> Soup.parse

let instantiate_template_for_index_page ~(template : Site.page)
    ~(header : Site.page) ~(content : Site.page) =
  Soup.replace (template $ "#page-content") content;
  Soup.replace (template $ "#header") header

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
  let header_component = get_header_component content_path in
  instantiate_template_for_index_page ~template:index_page
    ~header:header_component ~content:index_content_page;
  index_page

let generate_blog_page (content_path : Filename.t) =
  let blog_page_path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "blog.html" ])
  in
  let blog = blog_page_path |> In_channel.read_all |> Soup.parse in
  let header_component = get_header_component content_path in
  Soup.replace (blog $ "#header") header_component;
  blog

let generate site_generator =
  {
    index_page = generate_index_page site_generator.content_path;
    blog_page = generate_blog_page site_generator.content_path;
  }
