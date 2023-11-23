open Core

let main content_path out_path =
  let environment : Environment.environment = { content_path; out_path } in
  let site_generator = SiteGenerator.make environment in
  let site = SiteGenerator.generate site_generator in
  let site_directory = SiteDirectory.make environment in
  SiteDirectory.create site_directory ~index_page:site.index_page

let () =
  let content_path =
    Command.Param.flag "--content-path"
      ~doc:"Path of the site content directory"
      (Command.Flag.required Command.Param.string)
  in
  let out_path =
    Command.Param.flag "--out-path"
      ~doc:
        "Path of the generated site directory. If the path doesn't exist, it \
         will be created."
      (Command.Flag.required Command.Param.string)
  in
  let params = Command.Param.both content_path out_path in
  let command =
    Command.basic ~summary:"Generate static site from content"
      (Command.Param.map params ~f:(fun (content_path, out_path) () ->
           main content_path out_path))
  in
  Command_unix.run command
