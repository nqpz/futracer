default (i32, f32)

module I32 {
  type t = i32

  module D2 {
    type point = (t, t)
  }

  module D3 {
    type point = (t, t, t)
  }

  -- I know this is silly, but I wanted to try it.
  fun _signum_if_lt (a : t) (b : t) (case_then : t) (case_else : t) : t =
    let factor_then = (signum (b - a) + 1) / 2
    let factor_else = (signum (a - b) + 1) / 2 + signum (a - b) * signum (b - a) + 1
    in case_then * factor_then + case_else * factor_else

  fun min (a : t) (b : t) : t =
    _signum_if_lt a b a b

  fun max (a : t) (b : t) : t =
    _signum_if_lt b a a b

  fun min3 (a : t) (b : t) (c : t) : t =
    min (min a b) c

  fun max3 (a : t) (b : t) (c : t) : t =
    max (max a b) c
}
