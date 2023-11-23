open Core

let main project_root =
  let environment : Environment.environment = { project_root } in
  let site_generator = SiteGenerator.make environment in
  let site = SiteGenerator.generate site_generator in
  let site_directory = SiteDirectory.make environment ~out_dir:"dist" in
  SiteDirectory.create site_directory ~index_page:site.index_page

let () =
  let directory_flag =
    Command.Param.flag "--directory"
      (Command.Flag.required Command.Param.string)
      ~doc:"The directory path of inputs and outputs"
  in
  let command =
    Command.basic ~summary:"Generate static site from content"
      (Command.Param.map directory_flag ~f:(fun directory_flag () ->
           main directory_flag))
  in
  Command_unix.run command
