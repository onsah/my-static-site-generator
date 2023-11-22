let () =
  let site = SiteGenerator.generate () in
  SiteDirectory.create ~out_dir:"dist" ~index_page:site.index_page
