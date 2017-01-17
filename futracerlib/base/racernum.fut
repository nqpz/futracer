module type RACERNUM = {
  type t

  val min : t -> t -> t
  val max : t -> t -> t
  val abl : t -> t
  val mod : t -> t -> t
}

module RacerNumExtra (N : RACERNUM) = {
  type t = N.t

  fun min (a : t) (b : t) : t = N.min a b
  fun max (a : t) (b : t) : t = N.max a b
  fun abl (a : t) : t = N.abl a
  fun mod (a : t) (b : t) : t = N.mod a b

  type point2D = (t, t)
  type point3D = (t, t, t)
  type angles = (t, t, t)

  fun min3 (a : t) (b : t) (c : t) : t =
    N.min (N.min a b) c

  fun max3 (a : t) (b : t) (c : t) : t =
    N.max (N.max a b) c
}
