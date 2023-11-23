open Core

let () =
  let environment : Environment.environment =
    { project_root = Sys.getenv_exn "PROJECT_ROOT" }
  in
  let site_generator = SiteGenerator.make environment in
  let site = SiteGenerator.generate site_generator in
  let site_directory = SiteDirectory.make environment ~out_dir:"dist" in
  SiteDirectory.create site_directory ~index_page:site.index_page
