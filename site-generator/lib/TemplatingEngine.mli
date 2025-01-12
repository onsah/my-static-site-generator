open! Core

type html_document = Soup.soup Soup.node

type context_item =
    | String of string
    | Number of float



type context = (string, context_item, String.comparator_witness) Core.Map.t
    
(*  See: docs/Templating Engine.md 
    Performs in-place templating
*)
val perform_templating : doc:html_document -> context:context -> html_document
