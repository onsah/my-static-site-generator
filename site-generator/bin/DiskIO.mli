open Site

type path_type = File | Directory | Unknown

val get_type : Path.t -> path_type
val write_all : Path.t -> content:string -> unit

val create_dir : Path.t -> unit
(** Creates the directory with permissions: User: read write execute, rest: only read *)
