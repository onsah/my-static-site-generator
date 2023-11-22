(** Generates the HTML files for the given content *)

type site = {
    index_page : Templatizer.page;
}

val generate : unit -> site
