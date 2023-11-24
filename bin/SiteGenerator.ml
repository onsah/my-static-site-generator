open Core

let ( = ) = Poly.( = )
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

let hydrate_blog_page ~(blog_page : Site.page) ~(header_component : Site.page)
    ~(post_preview_components : Site.page list) =
  Soup.replace (blog_page $ "#header") header_component;
  ignore
    (List.map post_preview_components ~f:(fun preview ->
         Soup.append_child (blog_page $ "#posts") preview));
  ()

let generate_post_preview_component ~(content_path : Filename.t)
    ~(metadata : Yojson.Basic.t) =
  let post_preview_component =
    In_channel.read_all
      (Filename.concat content_path
         (Filename.of_parts [ "templates"; "post-preview.html" ]))
    |> Soup.parse
  in
  (* TODO: Parse the metadata into a record *)
  let title, created_at, summary =
    match metadata with
    | `Assoc fields ->
        (* TODO: Factor into function *)
        let title =
          match List.find fields ~f:(fun (name, _) -> name = "title") with
          | Some (_, `String title) -> title
          | Some _ ->
              raise (Invalid_argument "'title' field must contain string")
          | None ->
              raise (Invalid_argument "expected 'title' field in the metadata")
        in
        let created_at =
          match List.find fields ~f:(fun (name, _) -> name = "created-at") with
          | Some (_, `String created_at) -> created_at
          | Some _ ->
              raise (Invalid_argument "'created-at' field must contain string")
          | None ->
              raise
                (Invalid_argument "expected 'created-at' field in the metadata")
        in
        let summary =
          match List.find fields ~f:(fun (name, _) -> name = "summary") with
          | Some (_, `String summary) -> summary
          | Some _ ->
              raise (Invalid_argument "'summary' field must contain string")
          | None ->
              raise
                (Invalid_argument "expected 'summary' field in the metadata")
        in
        (title, created_at, summary)
    | _ -> raise (Invalid_argument "Expected json object")
  in
  (* Fill the component *)
  Soup.append_child (post_preview_component $ "#title") (Soup.create_text title);
  Soup.replace
    (post_preview_component $ "#created-at")
    (Soup.create_text created_at);
  Soup.replace (post_preview_component $ "#summary") (Soup.create_text summary);
  post_preview_component

let read_posts ~(content_path : Filename.t) =
  let pages_path =
    Filename.concat content_path (Filename.of_parts [ "pages"; "posts" ])
  in
  let file_paths = Sys_unix.readdir pages_path |> List.of_array in
  let metadata_file_names =
    List.filter file_paths ~f:(fun file ->
        Filename.split_extension file |> fun (_, ext) -> ext = Some "json")
  in
  let post_preview_components =
    List.map metadata_file_names ~f:(fun file_name ->
        let file_path = Filename.concat pages_path file_name in
        let metadata =
          file_path |> In_channel.read_all |> Yojson.Basic.from_string
        in
        generate_post_preview_component ~content_path ~metadata)
  in
  post_preview_components

let generate_blog_page (content_path : Filename.t) =
  let blog_page_path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "blog.html" ])
  in
  let blog_page = blog_page_path |> In_channel.read_all |> Soup.parse in
  let header_component = get_header_component content_path in
  let post_preview_components = read_posts ~content_path in
  hydrate_blog_page ~blog_page ~header_component ~post_preview_components;
  blog_page

let generate { content_path } =
  {
    index_page = generate_index_page content_path;
    blog_page = generate_blog_page content_path;
  }
