default (i32, f32)

struct F32 {
  type t = f32

  struct D2 {
    type point = (t, t)
  }

  struct D3 {
    type point = (t, t, t)
    type angles = (t, t, t)
  }

  fun min (a : t) (b : t) : t =
    if a < b
    then a
    else b

  fun max (a : t) (b : t) : t =
    if a > b
    then a
    else b

  fun min3 (a : t) (b : t) (c : t) : t =
    min (min a b) c

  fun max3 (a : t) (b : t) (c : t) : t =
    max (max a b) c

  fun abso (a : t) : t =
    if a < 0.0
    then -a
    else a

  fun mod (a : t) (m : t) : t =
    a - f32 (i32 (a / m)) * m
}
