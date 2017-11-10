import "/futlib/math"

import "/futracerlib/misc"

default (i32, f32)

type pixel = u32
type pixel_channel = u32
type rgb = (pixel_channel, pixel_channel, pixel_channel)
type hsv = (f32, f32, f32)

let pixel_get_r (p: pixel): pixel_channel =
  (p >> 16u32) & 255u32

let pixel_get_g (p: pixel): pixel_channel =
  (p >> 8u32) & 255u32

let pixel_get_b (p: pixel): pixel_channel =
  p & 255u32

let pixel_to_rgb (p: pixel): (pixel_channel, pixel_channel, pixel_channel) =
  (pixel_get_r p, pixel_get_g p, pixel_get_b p)

let rgb_to_pixel (r: pixel_channel, g: pixel_channel, b: pixel_channel): pixel =
  (r << 16u32) | (g << 8u32) | b

let hsv_to_rgb ((h, s, v): hsv): rgb =
  let c = v * s
  let h' = h / 60.0
  let x = c * (1.0 - f32.abs (fmod h' 2.0 - 1.0))
  let (r0, g0, b0) = if 0.0 <= h' && h' < 1.0
                     then (c, x, 0.0)
                     else if 1.0 <= h' && h' < 2.0
                     then (x, c, 0.0)
                     else if 2.0 <= h' && h' < 3.0
                     then (0.0, c, x)
                     else if 3.0 <= h' && h' < 4.0
                     then (0.0, x, c)
                     else if 4.0 <= h' && h' < 5.0
                     then (x, 0.0, c)
                     else if 5.0 <= h' && h' < 6.0
                     then (c, 0.0, x)
                     else (0.0, 0.0, 0.0)
  let m = v - c
  let (r, g, b) = (r0 + m, g0 + m, b0 + m)
  in (u32.f32 (255.0 * r), u32.f32 (255.0 * g), u32.f32 (255.0 * b))

let hsv_average
  ((h0, s0, v0): hsv)
  ((h1, s1, v1): hsv)
  : hsv =
  let (h0, h1) = if h0 < h1 then (h0, h1) else (h1, h0)
  let diff_a = h1 - h0
  let diff_b = h0 + 360.0 - h1
  let h = if diff_a < diff_b
          then h0 + diff_a / 2.0
          else fmod (h1 + diff_b / 2.0) 360.0
  let s = (s0 + s1) / 2.0
  let v = (v0 + v1) / 2.0
  in (h, s, v)
