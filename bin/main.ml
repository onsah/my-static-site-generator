
let () = 
  let site = SiteGenerator.generate () in
  SiteBuilder.create_directory ~out_dir:"dist" ~index_page:site.index_page
