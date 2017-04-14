import "futlib/math"
import "futracerlib/base/racernum"

default (i32, f32)

module I32Extra = RacerNumExtra({
  type t = i32

  -- I know this is silly, but I wanted to try it.
  fun _signum_if_lt (a: t) (b: t) (case_then: t) (case_else: t): t =
    let factor_then = (i32.sgn (b - a) + 1) / 2
    let factor_else = (i32.sgn (a - b) + 1) / 2 + i32.sgn (a - b) * i32.sgn (b - a) + 1
    in case_then * factor_then + case_else * factor_else

  fun min (a: t) (b: t): t =
    _signum_if_lt a b a b

  fun max (a: t) (b: t): t =
    _signum_if_lt b a a b

  fun abl (a: t): t =
    i32.abs a

  fun mod (a: t) (m: t): t =
    a % m
})
