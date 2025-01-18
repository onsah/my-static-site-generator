open! Core

type html_document = Soup.soup Soup.node

type context_item =
  | String of string
  | Number of float

type context = (string, context_item, String.comparator_witness) Core.Map.t

(** - [`UnexpectedCharacter] : An unexpected character found during parsing an identifier
    - [`EmptyIdentifier] : Identifier name between `\{\{` and `\}\}` is empty. *)
type templating_error_kind =
  [ `UnexpectedCharacter of char
  | `EmptyIdentifier
  ]

(** asdasd *)
type position =
  { line : int
  ; column : int
  }

type templating_error =
  { kind : templating_error_kind
  ; position : position
  }

(** - [doc] : the document to perform templating. Not modified.
    returns either the new document after templating, or list of errors happened during templating.
    For more details see: docs/Templating Engine.md 
*)
val perform_templating
  :  doc:html_document
  -> context:context
  -> (html_document, templating_error list) result
