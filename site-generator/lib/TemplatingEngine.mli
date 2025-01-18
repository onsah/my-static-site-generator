open! Core

type html_document = Soup.soup Soup.node

type context_item =
  | String of string
  | Number of float

type context = (string, context_item, String.comparator_witness) Core.Map.t

type templating_error_kind =
  [ `UnexpectedCharacter of char
  | `EmptyIdentifier
  ]

type position =
  { line : int
  ; column : int
  }

type templating_error =
  { kind : templating_error_kind
  ; position : position
  }

(*  See: docs/Templating Engine.md 
    Performs in-place templating
*)
val perform_templating
  :  doc:html_document
  -> context:context
  -> (html_document, templating_error list) result
