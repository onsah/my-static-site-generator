type page = Soup.soup Soup.node

type post = {
  title : string;
  page : page;
}

type t = {
  index_page : page;
  blog_page : page;
  style : string;  (** CSS file *)
  posts : post list;
}
