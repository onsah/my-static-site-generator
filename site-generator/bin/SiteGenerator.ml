open Core
open Templating
module Map = Core.Map.Poly

let ( = ) = Poly.( = )

open Site

let generate_html_from_markdown ~markdown_str =
  let doc = Cmarkit.Doc.of_string ~layout:true ~strict:false markdown_str in
  Cmarkit_html.of_doc ~safe:false doc

type post_metadata = {
  title : string;
  created_at : Date.t;
}

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
      { title; created_at }
  | _ -> raise (Invalid_argument "Expected json object")

let post_path ~(title : string) =
  "/posts/"
  ^ (title |> String.lowercase |> Str.global_replace (Str.regexp " ") "-")
  ^ ".html"

let post_path2 ~(title : string) =
  Path.join (Path.from "posts")
    (Path.from
       ((title |> String.lowercase |> Str.global_replace (Str.regexp " ") "-")
       ^ ".html"))

let extract_summary ~post_component =
  let component_text = post_component |> Soup.texts |> String.concat in
  let text_split = component_text |> String.split ~on:'.' in
  List.take text_split 3 @ [ "" ] |> String.concat ~sep:"."

let generate_style ~(content_path : Path.t) =
  let css_file_names = [ "simple.css"; "custom.css"; "highlight.css" ] in
  let css_file_paths =
    List.map css_file_names ~f:(fun filename ->
        Path.join content_path (Path.from_parts [ "css"; filename ]))
  in
  let css_file_contents = List.map css_file_paths ~f:DiskIO.read_all in
  (* Concat all styles *)
  String.concat css_file_contents ~sep:"\n"

let generate_font_files ~(content_path : Path.t) =
  let fonts_dir = Path.join content_path (Path.from_parts [ "css"; "fonts" ]) in
  let font_names = DiskIO.list fonts_dir in
  List.map font_names ~f:(fun name ->
      let path = Path.join fonts_dir name in
      {
        content = DiskIO.read_all path;
        path = Path.join (Path.from "fonts") name;
      })

let generate_components_context ~content_path : Context.context_item =
  let module Map = Core.Map.Poly in
  let open Context in
  let components_path = Path.join content_path (Path.from "components") in
  Object
    (components_path |> DiskIO.list
    |> List.map ~f:(fun path ->
           ( Path.base_name path,
             String (DiskIO.read_all (Path.join components_path path)) ))
    |> Map.of_alist_exn)

let generate_context ~content_path : Context.context =
  let module Map = Core.Map.Poly in
  let open Context in
  let pages_path = Path.join content_path (Path.from "pages") in
  let index =
    ( "index",
      String
        (generate_html_from_markdown
           ~markdown_str:
             (Path.join pages_path (Path.from "index.md") |> DiskIO.read_all))
    )
  in
  let posts =
    ( "posts",
      let posts_path = Path.join pages_path (Path.from "posts") in
      Collection
        (let posts_with_metadata =
           posts_path |> DiskIO.list
           |> List.filter ~f:(fun path -> Path.ext path = "md")
           |> List.map ~f:(fun path ->
                  let base_name = Path.base_name path in
                  let metadata_path =
                    Path.join posts_path (Path.from (base_name ^ ".json"))
                  in
                  let metadata =
                    metadata_path |> DiskIO.read_all |> Yojson.Basic.from_string
                  in
                  let metadata = parse_post_metadata ~metadata in
                  (path, metadata))
           |> List.sort ~compare:(fun (_, metadata1) (_, metadata2) ->
                  Date.compare metadata2.created_at metadata1.created_at)
         in
         posts_with_metadata
         |> List.map ~f:(fun (path, { title; created_at; _ }) ->
                let post_text =
                  generate_html_from_markdown
                    ~markdown_str:(Path.join posts_path path |> DiskIO.read_all)
                in
                let summary =
                  extract_summary ~post_component:(post_text |> Soup.parse)
                in
                Object
                  (Map.of_alist_exn
                     [
                       ("title", String title);
                       ("createdat", String (created_at |> Date.to_string));
                       ("createdatRfc822", String (created_at |> Rfc822.of_date));
                       ("summary", String summary);
                       ("path", String (post_path ~title));
                       ("content", String post_text);
                       ( "url",
                         String
                           (sprintf "https://blog.aiono.dev/%s"
                              (post_path2 ~title |> Path.to_string)) );
                     ]))) )
  in
  Map.of_alist_exn
    [ ("components", generate_components_context ~content_path); index; posts ]

let generate ~content_path =
  let context = generate_context ~content_path in
  let index_file =
    {
      content =
        TemplatingEngine.run
          ~template:
            (Path.join content_path
               (Path.from_parts [ "templates"; "index.html" ])
            |> DiskIO.read_all)
          ~context
        |> Result.map_error ~f:TemplatingEngine.show_error
        |> Result.ok_or_failwith;
      path = Path.from "index.html";
    }
  in
  let style_file =
    { content = generate_style ~content_path; path = Path.from "style.css" }
  in
  let font_files = generate_font_files ~content_path in
  let highlight_js_file =
    let highlight_js_path =
      Path.join content_path
        (Path.from_parts [ "highlight"; "highlight.min.js" ])
    in
    {
      content = DiskIO.read_all highlight_js_path;
      path = Path.from "highlight.js";
    }
  in
  let blog_file =
    {
      content =
        TemplatingEngine.run
          ~template:
            (Path.join content_path
               (Path.from_parts [ "templates"; "blog.html" ])
            |> DiskIO.read_all)
          ~context
        |> Result.map_error ~f:TemplatingEngine.show_error
        |> Result.ok_or_failwith;
      path = Path.from "blog.html";
    }
  in
  let post_files =
    let module Map = Core.Map.Poly in
    let posts_path =
      Path.join content_path (Path.from_parts [ "pages"; "posts" ])
    in
    let posts_with_metadata =
      posts_path |> DiskIO.list
      |> List.filter ~f:(fun path -> Path.ext path = "md")
      |> List.map ~f:(fun path ->
             let base_name = Path.base_name path in
             let metadata_path =
               Path.join posts_path (Path.from (base_name ^ ".json"))
             in
             let metadata =
               metadata_path |> DiskIO.read_all |> Yojson.Basic.from_string
             in
             let metadata = parse_post_metadata ~metadata in
             (path, metadata))
    in
    posts_with_metadata
    |> List.map ~f:(fun (path, { title; created_at }) ->
           let template =
             Path.join content_path
               (Path.from_parts [ "templates"; "post.html" ])
             |> DiskIO.read_all
           in
           let content =
             generate_html_from_markdown
               ~markdown_str:(DiskIO.read_all (Path.join posts_path path))
           in
           let context =
             Map.of_alist_exn
               Context.
                 [
                   ("title", String title);
                   ("createdat", String (created_at |> Date.to_string));
                   ("content", String content);
                   ("components", generate_components_context ~content_path);
                 ]
           in
           {
             content =
               TemplatingEngine.run ~template ~context
               |> Result.map_error ~f:TemplatingEngine.show_error
               |> Result.ok_or_failwith;
             path = post_path2 ~title;
           })
  and feed_file =
    let template =
      Path.join content_path (Path.from_parts [ "templates"; "feed.xml" ])
      |> DiskIO.read_all
    and context =
      let date = Date.today ~zone:Timezone.utc |> Rfc822.of_date in
      Map.add_exn context ~key:"pubDate" ~data:(String date)
    in
    {
      content =
        TemplatingEngine.run ~template ~context
        |> Result.map_error ~f:TemplatingEngine.show_error
        |> Result.ok_or_failwith;
      path = Path.from "feed.xml";
    }
  in
  {
    output_files =
      [ index_file; blog_file; style_file; highlight_js_file; feed_file ]
      @ font_files @ post_files;
  }
