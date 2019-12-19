(** Universal/heterogeneous maps, useful for storing values of arbitrary type in a single
    map.

    In order to recover a value, it must be looked up with exactly the [Key.t] it was
    stored in. In other words, given different [Key.t]s from the same [string], one will
    not be able to recover the key stored in the other one.

    This is similar to [Univ] in spirit.
*)

open! Import
module Key = Type_equal.Id

module type S = sig
  type t [@@deriving sexp_of]
  type 'a data

  include Invariant.S with type t := t

  val empty : t
  val is_empty : t -> bool
  val set : t -> 'a Key.t -> 'a data -> t
  val mem : t -> 'a Key.t -> bool
  val mem_by_id : t -> Key.Uid.t -> bool
  val find : t -> 'a Key.t -> 'a data option
  val find_exn : t -> 'a Key.t -> 'a data
  val add : t -> 'a Key.t -> 'a data -> [ `Ok of t | `Duplicate ]
  val add_exn : t -> 'a Key.t -> 'a data -> t
  val change : t -> 'a Key.t -> f:('a data option -> 'a data option) -> t
  val change_exn : t -> 'a Key.t -> f:('a data -> 'a data) -> t
  val update : t -> 'a Key.t -> f:('a data option -> 'a data) -> t
  val remove : t -> 'a Key.t -> t
  val remove_by_id : t -> Key.Uid.t -> t

  module Packed : sig
    type t = T : 'a Key.t * 'a data -> t
  end

  val to_alist : t -> Packed.t list
  val of_alist_exn : Packed.t list -> t
end

module type S1 = sig
  (** The ['s] parameter is shared across all values stored in the map. *)
  type 's t [@@deriving sexp_of]

  type ('s, 'a) data

  val invariant : _ t -> unit
  val empty : _ t
  val is_empty : _ t -> bool
  val set : 's t -> 'a Key.t -> ('s, 'a) data -> 's t
  val mem : _ t -> _ Key.t -> bool
  val mem_by_id : _ t -> Key.Uid.t -> bool
  val find : 's t -> 'a Key.t -> ('s, 'a) data option
  val find_exn : 's t -> 'a Key.t -> ('s, 'a) data
  val add : 's t -> 'a Key.t -> ('s, 'a) data -> [ `Ok of 's t | `Duplicate ]
  val add_exn : 's t -> 'a Key.t -> ('s, 'a) data -> 's t

  val change
    :  's t
    -> 'a Key.t
    -> f:(('s, 'a) data option -> ('s, 'a) data option)
    -> 's t

  val change_exn : 's t -> 'a Key.t -> f:(('s, 'a) data -> ('s, 'a) data) -> 's t
  val update : 's t -> 'a Key.t -> f:(('s, 'a) data option -> ('s, 'a) data) -> 's t
  val remove : 's t -> 'a Key.t -> 's t
  val remove_by_id : 's t -> Key.Uid.t -> 's t

  module Packed : sig
    type 's t = T : 'a Key.t * ('s, 'a) data -> 's t
  end

  val to_alist : 's t -> 's Packed.t list
  val of_alist_exn : 's Packed.t list -> 's t
end

module type Univ_map = sig
  module type S = S
  module type S1 = S1

  module Key = Key
  include S with type 'a data = 'a

  module Make (Data : sig
      type 'a t [@@deriving sexp_of]
    end) : S with type 'a data = 'a Data.t

  module Make1 (Data : sig
      type ('s, 'a) t [@@deriving sexp_of]
    end) : S1 with type ('s, 'a) data = ('s, 'a) Data.t

  (** keys with associated default values, so that [find] is no longer partial *)
  module With_default : sig
    module Key : sig
      type 'a t

      val create : default:'a -> name:string -> ('a -> Sexp.t) -> 'a t
      val id : 'a t -> 'a Type_equal.Id.t
    end

    val set : t -> 'a Key.t -> 'a -> t
    val find : t -> 'a Key.t -> 'a
    val change : t -> 'a Key.t -> f:('a -> 'a) -> t
  end

  (** keys that map to an accumulator value with an associated fold operation *)
  module With_fold : sig
    module Key : sig
      type ('a, 'b) t

      val create
        :  init:'b
        -> f:('b -> 'a -> 'b)
        -> name:string
        -> ('b -> Sexp.t)
        -> ('a, 'b) t

      val id : ('a, 'b) t -> 'b Type_equal.Id.t
    end

    (** reset the accumulator *)
    val set : t -> ('a, 'b) Key.t -> 'b -> t

    (** the current accumulator *)
    val find : t -> ('a, 'b) Key.t -> 'b

    (** fold value into accumulator *)
    val add : t -> ('a, 'b) Key.t -> 'a -> t

    (** accumulator update *)
    val change : t -> ('a, 'b) Key.t -> f:('b -> 'b) -> t
  end

  (** list-accumulating keys with a default value of the empty list *)
  module Multi : sig
    module Key : sig
      type 'a t

      val create : name:string -> ('a -> Sexp.t) -> 'a t
      val id : 'a t -> 'a list Type_equal.Id.t
    end

    val set : t -> 'a Key.t -> 'a list -> t
    val find : t -> 'a Key.t -> 'a list
    val add : t -> 'a Key.t -> 'a -> t
    val change : t -> 'a Key.t -> f:('a list -> 'a list) -> t
  end
end
