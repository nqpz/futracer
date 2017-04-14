import "futracerlib/base/racernum"

default (i32, f32)

module F32Extra = RacerNumExtra(  {
  type t = f32

  fun min (a: t) (b: t): t =
    if a < b
    then a
    else b

  fun max (a: t) (b: t): t =
    if a > b
    then a
    else b

  fun abl (a: t): t =
    if a < 0.0
    then -a
    else a

  fun mod (a: t) (m: t): t =
    a - f32 (i32 (a / m)) * m
})
