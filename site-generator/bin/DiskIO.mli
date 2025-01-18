open Site

type path_type = File | Directory | Unknown

val get_type : Path.t -> path_type
val write_all : Path.t -> content:string -> unit
val read_all : Path.t -> string

val list : Path.t -> Path.t list
(** Lists the children under a directory. Assumes the path corresponds to a
    directory. *)

val create_dir : Path.t -> unit
(** Creates the directory with permissions: User: read write execute, rest: only
    read *)
