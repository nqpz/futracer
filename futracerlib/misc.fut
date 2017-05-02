import "/futlib/math"

default (i32, f32)

module type racer_num = {
  type t
}

module racer (num: racer_num) = {
  type t = num.t

  type point2D = (t, t)
  type point3D = (t, t, t)
  type angles = (t, t, t)
}

module f32racer = racer {
  type t = f32
}

module i32racer = racer {
  type t = i32
}

let fmod (a: f32) (m: f32): f32 =
  a - f32 (i32 (a / m)) * m

let in_range (t: i32) (a: i32) (b: i32): bool =
  (a < b && a <= t && t <= b) || (b <= a && b <= t && t <= a)

let within_bounds
  (smallest: i32) (highest: i32)
  (n: i32): i32 =
  i32.max smallest (i32.min highest n)
