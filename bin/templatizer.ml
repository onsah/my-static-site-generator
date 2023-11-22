
type page = Soup.soup Soup.node

let sprintf = Printf.sprintf

let ($) = Soup.($)

let current_dir = Core.Sys.getenv_exn "PROJECT_ROOT"

let index_template_path = (sprintf "%s/content/templates/template.html" current_dir) 

let generate_index_page ~content = 
  let 
    template = index_template_path
      |> Core.In_channel.read_all
      |> Soup.parse 
  in
  Soup.replace (template $ "#page-content") content;
  template
