open Core

let main content_path out_path =
  let content_path = Site.Path.from content_path in
  let site = SiteGenerator.generate ~content_path in
  SiteDirectory.create ~site ~at:(Site.Path.from out_path)

let command =
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
  Command.basic ~summary:"Generate static site from content"
    (Command.Param.map params ~f:(fun (content_path, out_path) () ->
         main content_path out_path))

let () = Command_unix.run command
