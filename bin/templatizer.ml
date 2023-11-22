

let sprintf = Printf.sprintf

let ($) = Soup.($)

let index_template_path = (sprintf "%s/content/templates/template.html" Environment.project_root) 

let generate_index_page ~content = 
  let 
    template = index_template_path
      |> Core.In_channel.read_all
      |> Soup.parse 
  in
  Soup.replace (template $ "#page-content") content;
  template
