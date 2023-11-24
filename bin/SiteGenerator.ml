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

let hydrate_index_page ~(index_page : Site.page) ~(header_component : Site.page)
    ~(content_component : Site.page) =
  Soup.replace (index_page $ "#page-content") content_component;
  Soup.replace (index_page $ "#header") header_component

let generate_index_page (content_path : Filename.t) =
  let index_content_path =
    Filename.concat content_path (Filename.of_parts [ "pages"; "index.md" ])
  in
  let content_component =
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
  hydrate_index_page ~index_page ~header_component ~content_component;
  index_page

let hydrate_blog_page ~(blog_page : Site.page) ~(header_component : Site.page) =
  Soup.replace (blog_page $ "#header") header_component

let generate_blog_page (content_path : Filename.t) =
  let blog_page_path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "blog.html" ])
  in
  let blog_page = blog_page_path |> In_channel.read_all |> Soup.parse in
  let header_component = get_header_component content_path in
  hydrate_blog_page ~blog_page ~header_component;
  blog_page

let generate { content_path } =
  {
    index_page = generate_index_page content_path;
    blog_page = generate_blog_page content_path;
  }
