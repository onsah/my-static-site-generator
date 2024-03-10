open Core

let ( = ) = Poly.( = )
let ( $ ) = Soup.( $ )

open Site

type site_generator = { content_path : Filename.t }
type post_with_preview = { preview : Site.page; post : Site.post }

let make ~content_path = { content_path }

let generate_html_from_markdown ~markdown_str =
  let markdown = Omd.of_string markdown_str in
  Omd.to_html markdown

let generate_header_component (content_path : Filename.t) =
  let path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "header.html" ])
  in
  path |> In_channel.read_all |> Soup.parse

let hydrate_index_page ~(index_page : Site.page) ~(header_component : Site.page)
    ~(content_component : Site.page) =
  Soup.replace (index_page $ "#page-content") content_component;
  Soup.replace (index_page $ "#header") header_component

let clone_page (page : Site.page) : page =
  Soup.parse (Soup.to_string page)

let generate_index_page ~(content_path : Filename.t) =
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
  let header_component = generate_header_component content_path in
  hydrate_index_page ~index_page ~header_component ~content_component;
  index_page

let hydrate_blog_page ~(blog_page : Site.page) ~(header_component : Site.page)
    ~(post_preview_components : Site.page list) =
  Soup.replace (blog_page $ "#header") header_component;
  ignore
    (List.map post_preview_components ~f:(fun preview ->
         Soup.append_child (blog_page $ "#posts") preview));
  ()

type post_metadata = { title : string; created_at : Date.t; summary : string }

let parse_post_metadata ~(metadata : Yojson.Basic.t) : post_metadata =
  let extract_string_field ~fields ~field_name =
    match List.find fields ~f:(fun (name, _) -> name = field_name) with
    | Some (_, `String field_value) -> field_value
    | Some _ ->
        raise
          (Invalid_argument
             (sprintf "'%s' field must contain string" field_name))
    | None ->
        raise
          (Invalid_argument
             (sprintf "expected '%s' field in the metadata" field_name))
  in
  match metadata with
  | `Assoc fields ->
      let title = extract_string_field ~fields ~field_name:"title" in
      let created_at =
        extract_string_field ~fields ~field_name:"created-at" |> Date.of_string
      in
      let summary = extract_string_field ~fields ~field_name:"summary" in
      { title; created_at; summary }
  | _ -> raise (Invalid_argument "Expected json object")

let date_to_string date =
  sprintf "%i %s %i" (Date.day date)
    (Month.to_string (Date.month date))
    (Date.year date)

let post_path ~(title : string) =
  "/posts/" 
    ^ (title |> String.lowercase |> 
        (Str.global_replace (Str.regexp " ") "-")) 
    ^ ".html"

let generate_post_components 
    ~(content_path : Filename.t)
    ~(metadata : Yojson.Basic.t)
    ~(header_component : Site.page) : post_with_preview =
  let preview =
    In_channel.read_all
      (Filename.concat content_path
         (Filename.of_parts [ "templates"; "post-preview.html" ]))
    |> Soup.parse
  in
  let { title; created_at; summary } = parse_post_metadata ~metadata in
  let post_path = post_path ~title
  in
  (* Fill the preview component *)
  Soup.append_child (preview $ "#title") (Soup.create_text title);
  Soup.replace (preview $ "#created-at")
    (Soup.create_text (date_to_string created_at));
  Soup.replace (preview $ "#summary") (Soup.create_text summary);
  Soup.set_attribute "href" post_path (preview $ "#post-link");
  let page =
    In_channel.read_all
      (Filename.concat content_path
         (Filename.of_parts [ "templates"; "post.html" ]))
    |> Soup.parse
  in
  (* Fill the post page *)
  Soup.replace (page $ "#header") header_component;
  { preview; post = { title; page; path = post_path } }

let generate_post_components_list 
  ~(content_path : Filename.t)
  ~(header_component : Site.page) : post_with_preview list
    =
  let pages_path =
    Filename.concat content_path (Filename.of_parts [ "pages"; "posts" ])
  in
  let file_paths = Sys_unix.readdir pages_path |> List.of_array in
  let metadata_file_names =
    List.filter file_paths ~f:(fun file ->
        Filename.split_extension file |> fun (_, ext) -> ext = Some "json")
  in
  let post_components_list =
    List.map metadata_file_names ~f:(fun file_name ->
        let file_path = Filename.concat pages_path file_name in
        let metadata =
          file_path |> In_channel.read_all |> Yojson.Basic.from_string
        in
        generate_post_components ~content_path ~metadata ~header_component:(clone_page header_component))
  in
  post_components_list

let generate_blog_page ~(content_path : Filename.t) ~(header_component : Site.page) =
  let blog_page_path =
    Filename.concat content_path
      (Filename.of_parts [ "templates"; "blog.html" ])
  in
  let blog_page = blog_page_path |> In_channel.read_all |> Soup.parse in
  let post_components_list = generate_post_components_list ~content_path ~header_component in
  hydrate_blog_page ~blog_page ~header_component
    ~post_preview_components:
      (List.map post_components_list ~f:(fun { preview; _ } -> preview));
  blog_page

let generate_posts ~(content_path : Filename.t) ~(header_component : Site.page) =
  let post_components_list = generate_post_components_list ~content_path ~header_component
  in
  List.map post_components_list ~f:(fun { post ; _ } -> post)

let generate_style ~(content_path : Filename.t) =
  let css_pico_path =
    Filename.concat content_path
      (Filename.of_parts [ "css"; "pico-1.5.10"; "css"; "pico.min.css" ])
  and css_custom_path =
    Filename.concat content_path (Filename.of_parts [ "css"; "custom.css" ])
  in
  let css_pico = In_channel.read_all css_pico_path
  and css_custom = In_channel.read_all css_custom_path in
  (* Concat all styles *)
  String.concat [ css_pico; css_custom ] ~sep:"\n"

let generate { content_path } =
  let header_component = generate_header_component content_path in
  {
    index_page = generate_index_page ~content_path;
    blog_page = generate_blog_page ~content_path
      ~header_component:(clone_page header_component);
    style = generate_style ~content_path;
    posts = generate_posts ~content_path ~header_component:(clone_page header_component);
  }
