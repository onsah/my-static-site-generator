open Core

let () =
  let environment : Environment.environment =
    { project_root = Sys.getenv_exn "PROJECT_ROOT" }
  in
  let site_generator = SiteGenerator.make environment in
  let site = SiteGenerator.generate site_generator in
  SiteDirectory.create ~out_dir:"dist" ~index_page:site.index_page
