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

type templating_error_kind =
  [ `TokenizerExpectedOneOf of char list
  | `TokenizerUnexpected of char
  | `Unexpected of string
  | `VariableNotFound of string
  | `FinishedUnexpectedly
  ]

(** A position in the HTML document. *)
type location =
  { line : int
  ; column : int
  }

type templating_error =
  { kind : templating_error_kind
  ; position : location
  }

(**
  returns either the new document after templating, or list of errors happened during templating.
*)
val run
  :  template:string
  -> context:context
  (* TODO: error list *)
  -> (string, templating_error) result
