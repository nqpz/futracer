module type racer_num = {
  type t
}

module racer (num: racer_num) = {
  type t = num.t

  type point2D = (t, t)
  type point3D = (t, t, t)
  type angles = (t, t, t)
}

module f32racer = racer({
  type t = f32
})

module i32racer = racer({
  type t = i32
})

fun fmod (a: f32) (m: f32): f32 =
  a - f32 (i32 (a / m)) * m
