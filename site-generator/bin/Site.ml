type page = Soup.soup Soup.node

type post = {
  title : string;
  (* path of the post in the website hiearachy *)
  path : string;
  page : page;
}

type t = {
  index_page : page;
  blog_page : page;
  style : string;  (** CSS file *)
  posts : post list;
}
