open! Core

(** I use the version of the map where comparator is polymorphic *)
module Map = Core.Map.Poly

type html_document = Soup.soup Soup.node

(** Type of the values for template variables *)
type context_item =
  | String of string
  | Number of float

(** Mapping from template variables to their values. *)
type context = (string, context_item) Map.t

(** - [`UnexpectedCharacter] : An unexpected character found during parsing an identifier
    - [`EmptyIdentifier] : Identifier name between `\{\{` and `\}\}` is empty. *)
type templating_error_kind =
  [ `UnexpectedCharacter of char
  | `EmptyIdentifier
  ]

(** A position in the HTML document. *)
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
    - [context]
*)
val perform_templating
  :  doc:html_document
  -> context:context
  -> (html_document, templating_error list) result
