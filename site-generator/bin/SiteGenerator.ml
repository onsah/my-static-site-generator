open Core
open Templating_engine

let ( = ) = Poly.( = )
let ( $ ) = Soup.( $ )

open Site

type post_with_preview =
  { preview : Site.page
  ; post : Site.post
  }

type current_section = Me

let generate_html_from_markdown ~markdown_str =
  let doc = Cmarkit.Doc.of_string ~layout:true ~strict:false markdown_str in
  Cmarkit_html.of_doc ~safe:false doc
;;

let generate_header_component (content_path : Path.t) ~(current_section : current_section)
  =
  let path = Path.join content_path (Path.from_parts [ "templates"; "header.html" ]) in
  let header_component = path |> DiskIO.read_all |> Soup.parse in
  (match current_section with
   | Me -> Soup.add_class "current" (header_component $ "#me"));
  header_component
;;

let hydrate_index_page
      ~(index_page : Site.page)
      ~(header_component : Site.page)
      ~(content_component : Site.page)
  =
  Soup.replace (index_page $ "#page-content") content_component;
  Soup.replace (index_page $ "#header") header_component
;;

let clone_page (page : Site.page) : page = Soup.parse (Soup.to_string page)

let _generate_index_page ~(content_path : Path.t) =
  let index_content_path =
    Path.join content_path (Path.from_parts [ "pages"; "index.md" ])
  in
  let content_component =
    generate_html_from_markdown ~markdown_str:(index_content_path |> DiskIO.read_all)
    |> Soup.parse
  in
  let index_page_path =
    Path.join content_path (Path.from_parts [ "templates"; "index.html" ])
  in
  let index_page = index_page_path |> DiskIO.read_all |> Soup.parse in
  let header_component = generate_header_component content_path ~current_section:Me in
  hydrate_index_page ~index_page ~header_component ~content_component;
  index_page
;;

let hydrate_blog_page
      ~(blog_page : Site.page)
      ~(header_component : Site.page)
      ~(post_preview_components : Site.page list)
  =
  Soup.replace (blog_page $ "#header") header_component;
  ignore
    (List.map post_preview_components ~f:(fun preview ->
       Soup.append_child (blog_page $ "#posts") preview));
  ()
;;

type post_metadata =
  { title : string
  ; created_at : Date.t
  }

let parse_post_metadata ~(metadata : Yojson.Basic.t) : post_metadata =
  let extract_string_field ~fields ~field_name =
    match List.find fields ~f:(fun (name, _) -> name = field_name) with
    | Some (_, `String field_value) -> field_value
    | Some _ ->
      raise (Invalid_argument (sprintf "'%s' field must contain string" field_name))
    | None ->
      raise (Invalid_argument (sprintf "expected '%s' field in the metadata" field_name))
  in
  match metadata with
  | `Assoc fields ->
    let title = extract_string_field ~fields ~field_name:"title" in
    let created_at =
      extract_string_field ~fields ~field_name:"created-at" |> Date.of_string
    in
    { title; created_at }
  | _ -> raise (Invalid_argument "Expected json object")
;;

let date_to_string date =
  sprintf "%i %s %i" (Date.day date) (Month.to_string (Date.month date)) (Date.year date)
;;

let post_path ~(title : string) =
  "/posts/"
  ^ (title |> String.lowercase |> Str.global_replace (Str.regexp " ") "-")
  ^ ".html"
;;

let post_path2 ~(title : string) =
  Path.join
    (Path.from "posts")
    (Path.from
       ((title |> String.lowercase |> Str.global_replace (Str.regexp " ") "-") ^ ".html"))
;;

let extract_summary ~post_component =
  let component_text = post_component |> Soup.texts |> String.concat in
  let text_split = component_text |> String.split ~on:'.' in
  List.take text_split 3 @ [ "" ] |> String.concat ~sep:"."
;;

let generate_post_components
      ~(content_path : Path.t)
      ~(metadata : Yojson.Basic.t)
      ~(post_component : Site.page)
      ~(header_component : Site.page)
  : post_with_preview
  =
  let preview =
    DiskIO.read_all
      (Path.join content_path (Path.from_parts [ "templates"; "post-preview.html" ]))
    |> Soup.parse
  in
  let { title; created_at; _ } = parse_post_metadata ~metadata in
  let summary = extract_summary ~post_component in
  let post_path = post_path ~title in
  let path = post_path2 ~title in
  (* Fill the preview component *)
  Soup.append_child (preview $ "#title") (Soup.create_text title);
  Soup.replace (preview $ "#created-at") (Soup.create_text (date_to_string created_at));
  Soup.replace (preview $ "#summary") (Soup.create_text summary);
  Soup.set_attribute "href" post_path (preview $ "#post-link");
  let page =
    DiskIO.read_all
      (Path.join content_path (Path.from_parts [ "templates"; "post.html" ]))
    |> Soup.parse
  in
  (* Fill the post page *)
  Soup.replace (page $ "#header") header_component;
  Soup.replace (page $ "#blog-content") post_component;
  Soup.replace (page $ "#post-title-header") (Soup.create_element "h1" ~inner_text:title);
  Soup.replace (page $ "#created-at") (Soup.create_text (date_to_string created_at));
  { preview; post = { title; created_at; page; path = post_path; path2 = path } }
;;

let generate_post_components_list ~(content_path : Path.t) ~(header_component : Site.page)
  : post_with_preview list
  =
  let pages_path = Path.join content_path (Path.from_parts [ "pages"; "posts" ]) in
  let file_names = DiskIO.list pages_path in
  let file_names_before_ext =
    file_names
    |> List.filter_map ~f:(fun path ->
      let file = Path.to_string path in
      let file_name_before_ext, ext = file |> Filename.split_extension in
      match ext with
      | Some "md" -> Some file_name_before_ext
      | _ -> None)
  in
  let post_components_list =
    List.map file_names_before_ext ~f:(fun file_name_before_ext ->
      let metadata_path =
        Path.join pages_path (Path.from (file_name_before_ext ^ ".json"))
      in
      let metadata = metadata_path |> DiskIO.read_all |> Yojson.Basic.from_string in
      let post_path = Path.join pages_path (Path.from (file_name_before_ext ^ ".md")) in
      let post_component =
        generate_html_from_markdown ~markdown_str:(post_path |> DiskIO.read_all)
        |> Soup.parse
      in
      generate_post_components
        ~content_path
        ~metadata
        ~post_component
        ~header_component:(clone_page header_component))
  in
  let post_components_list =
    List.sort
      post_components_list
      ~compare:(fun { post = post1; _ } { post = post2; _ } ->
        -Date.compare post1.created_at post2.created_at)
  in
  post_components_list
;;

let _generate_blog_page ~(content_path : Path.t) ~(header_component : Site.page) =
  let blog_page_path =
    Path.join content_path (Path.from_parts [ "templates"; "blog.html" ])
  in
  let blog_page = blog_page_path |> DiskIO.read_all |> Soup.parse in
  let post_components_list =
    generate_post_components_list ~content_path ~header_component
  in
  hydrate_blog_page
    ~blog_page
    ~header_component
    ~post_preview_components:
      (List.map post_components_list ~f:(fun { preview; _ } -> preview));
  blog_page
;;

let _generate_posts ~(content_path : Path.t) ~(header_component : Site.page) =
  let post_components_list =
    generate_post_components_list ~content_path ~header_component
  in
  List.map post_components_list ~f:(fun { post; _ } -> post)
;;

let generate_style ~(content_path : Path.t) =
  let css_file_names = [ "simple.css"; "custom.css"; "highlight.css" ] in
  let css_file_paths =
    List.map css_file_names ~f:(fun filename ->
      Path.join content_path (Path.from_parts [ "css"; filename ]))
  in
  let css_file_contents = List.map css_file_paths ~f:DiskIO.read_all in
  (* Concat all styles *)
  String.concat css_file_contents ~sep:"\n"
;;

let generate_font_files ~(content_path : Path.t) =
  let fonts_dir = Path.join content_path (Path.from_parts [ "css"; "fonts" ]) in
  let font_names = DiskIO.list fonts_dir in
  List.map font_names ~f:(fun name ->
    let path = Path.join fonts_dir name in
    { content = DiskIO.read_all path; path = Path.join (Path.from "fonts") name })
;;

let generate_components_context ~content_path : TemplatingEngine.context_item =
  let module Map = Core.Map.Poly in
  let open TemplatingEngine in
  let components_path = Path.join content_path (Path.from "components") in
  Object
    (components_path
     |> DiskIO.list
     |> List.map ~f:(fun path ->
       Path.base_name path, String (DiskIO.read_all (Path.join components_path path)))
     |> Map.of_alist_exn)
;;

let generate_context ~content_path : TemplatingEngine.context =
  let module Map = Core.Map.Poly in
  let open TemplatingEngine in
  let pages_path = Path.join content_path (Path.from "pages") in
  let index =
    ( "index"
    , String
        (generate_html_from_markdown
           ~markdown_str:(Path.join pages_path (Path.from "index.md") |> DiskIO.read_all))
    )
  in
  let posts =
    ( "posts"
    , let posts_path = Path.join pages_path (Path.from "posts") in
      Collection
        (let posts_with_metadata =
           posts_path
           |> DiskIO.list
           |> List.filter ~f:(fun path -> Path.ext path = "md")
           |> List.map ~f:(fun path ->
             let base_name = Path.base_name path in
             let metadata_path = Path.join posts_path (Path.from (base_name ^ ".json")) in
             let metadata =
               metadata_path |> DiskIO.read_all |> Yojson.Basic.from_string
             in
             let metadata = parse_post_metadata ~metadata in
             path, metadata)
           |> List.sort ~compare:(fun (_, metadata1) (_, metadata2) ->
             Date.compare metadata2.created_at metadata1.created_at)
         in
         posts_with_metadata
         |> List.map ~f:(fun (path, { title; created_at; _ }) ->
           let post_text =
             generate_html_from_markdown
               ~markdown_str:(Path.join posts_path path |> DiskIO.read_all)
           in
           let summary = extract_summary ~post_component:(post_text |> Soup.parse) in
           Object
             (Map.of_alist_exn
                [ "title", String title
                ; "createdat", String (created_at |> Date.to_string)
                ; "summary", String summary
                ; "path", String (post_path ~title)
                ; "content", String post_text
                ]))) )
  in
  Map.of_alist_exn
    [ "components", generate_components_context ~content_path; index; posts ]
;;

let generate ~content_path =
  let context = generate_context ~content_path in
  let index_file =
    { content =
        TemplatingEngine.run
          ~template:
            (Path.join content_path (Path.from_parts [ "templates"; "index.new.html" ])
             |> DiskIO.read_all)
          ~context
        |> Result.map_error ~f:TemplatingEngine.show_error
        |> Result.ok_or_failwith
    ; path = Path.from "index.html"
    }
  in
  let style_file =
    { content = generate_style ~content_path; path = Path.from "style.css" }
  in
  let font_files = generate_font_files ~content_path in
  let highlight_js_file =
    let highlight_js_path =
      Path.join content_path (Path.from_parts [ "highlight"; "highlight.min.js" ])
    in
    { content = DiskIO.read_all highlight_js_path; path = Path.from "highlight.js" }
  in
  let blog_file =
    { content =
        TemplatingEngine.run
          ~template:
            (Path.join content_path (Path.from_parts [ "templates"; "blog.new.html" ])
             |> DiskIO.read_all)
          ~context
        |> Result.map_error ~f:TemplatingEngine.show_error
        |> Result.ok_or_failwith
    ; path = Path.from "blog.html"
    }
  in
  let post_files =
    let module Map = Core.Map.Poly in
    let posts_path = Path.join content_path (Path.from_parts [ "pages"; "posts" ]) in
    let posts_with_metadata =
      posts_path
      |> DiskIO.list
      |> List.filter ~f:(fun path -> Path.ext path = "md")
      |> List.map ~f:(fun path ->
        let base_name = Path.base_name path in
        let metadata_path = Path.join posts_path (Path.from (base_name ^ ".json")) in
        let metadata = metadata_path |> DiskIO.read_all |> Yojson.Basic.from_string in
        let metadata = parse_post_metadata ~metadata in
        path, metadata)
    in
    posts_with_metadata
    |> List.map ~f:(fun (path, { title; created_at }) ->
      let template =
        Path.join content_path (Path.from_parts [ "templates"; "post.new.html" ])
        |> DiskIO.read_all
      in
      let content =
        generate_html_from_markdown
          ~markdown_str:(DiskIO.read_all (Path.join posts_path path))
      in
      let context =
        Map.of_alist_exn
          TemplatingEngine.
            [ "title", String title
            ; "createdat", String (created_at |> Date.to_string)
            ; "content", String content
            ; "components", generate_components_context ~content_path
            ]
      in
      { content =
          TemplatingEngine.run ~template ~context
          |> Result.map_error ~f:TemplatingEngine.show_error
          |> Result.ok_or_failwith
      ; path = post_path2 ~title
      })
  in
  (* let post_files =
    List.map
      (generate_posts ~content_path ~header_component:(clone_page header_component))
      ~f:(fun post -> { content = post.page |> Soup.to_string; path = post.path2 })
  in *)
  { output_files =
      [ index_file; blog_file; style_file; highlight_js_file ] @ font_files @ post_files
  }
;;
