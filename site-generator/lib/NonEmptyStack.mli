type 'a t

val top : 'a t -> 'a
val make : 'a -> 'a t
val push : 'a t -> 'a -> 'a t
val pop : 'a t -> 'a * 'a t option
val find_map : 'a t -> f:('a -> 'b option) -> 'b option
