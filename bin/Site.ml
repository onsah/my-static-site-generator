type page = Soup.soup Soup.node

type t = {
  index_page : page;
  blog_page : page;  (** CSS file *)
  style : string;
}
