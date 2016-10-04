default (i32, f32)

struct F32 {
  type t = f32

  struct D2 {
    type point = (t, t)
  }

  struct D3 {
    type point = (t, t, t)
    type angle = (t, t, t)
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

  fun mod (a : t, m : t) : t =
    a - f32 (i32 (a / m)) * m
}

struct I32 {
  type t = i32

  struct D2 {
    type point = (t, t)
  }

  struct D3 {
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

type triangle = (F32.D3.point, F32.D3.point, F32.D3.point)
type point_projected = (i32, i32, f32)
type triangle_projected = (point_projected, point_projected, point_projected)
type point_barycentric = (i32, I32.D3.point, F32.D3.point)
type camera = (F32.D3.point, F32.D3.angle)
type pixel = u32
type pixel_channel = u32

fun pixel_get_r (p : pixel) : pixel_channel =
  (p >> 16u32) & 255u32

fun pixel_get_g (p : pixel) : pixel_channel =
  (p >> 8u32) & 255u32

fun pixel_get_b (p : pixel) : pixel_channel =
  p & 255u32

fun pixel_to_rgb (p : pixel) : (pixel_channel, pixel_channel, pixel_channel) =
  (pixel_get_r p, pixel_get_g p, pixel_get_b p)

fun rgb_to_pixel (r : pixel_channel, g : pixel_channel, b : pixel_channel) : pixel =
  (r << 16u32) | (g << 8u32) | b

fun hsv_to_rgb (h : f32, s : f32, v : f32) : (pixel_channel, pixel_channel, pixel_channel) =
  let c = v * s
  let h' = h / 60.0
  let x = c * (1.0 - F32.abso (F32.mod (h', 2.0) - 1.0))
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
  in (u32 (255.0 * r), u32 (255.0 * g), u32 (255.0 * b))

fun floor (t : f32) : i32 =
  i32 t

fun ceil (t : f32) : i32 =
  i32 t + 1

fun bound (max : i32) (t : i32) : i32 =
  I32.min (max - 1) (I32.max 0 t)
  
fun project_point
  (camera : camera)
  ((x, y, z) : F32.D3.point)
  : I32.D2.point =
  let ((xc, yc, zc), (ax, ay, az)) = camera
  let t = 1.0 - z
  in (i32 (x * t), i32 (y * t))

fun in_range (t : i32) (a : i32) (b : i32) : bool =
  (a < b && a <= t && t <= b) || (b <= a && b <= t && t <= a)
  
fun barycentric_coordinates
  (triangle : triangle_projected)
  ((x, y) : I32.D2.point)
  : point_barycentric =
  let ((xp0, yp0, _z0), (xp1, yp1, _z1), (xp2, yp2, _z2)) = triangle
  let factor = (yp1 - yp2) * (xp0 - xp2) + (xp2 - xp1) * (yp0 - yp2)
  let a = ((yp1 - yp2) * (x - xp2) + (xp2 - xp1) * (y - yp2))
  let b = ((yp2 - yp0) * (x - xp2) + (xp0 - xp2) * (y - yp2))
  let c = factor - a - b
  let factor' = f32 factor
  let an = f32 a / factor'
  let bn = f32 b / factor'
  let cn = 1.0 - an - bn
  in (factor, (a, b, c), (an, bn, cn))

fun is_inside_triangle
  ((factor, (a, b, c), (_an, _bn, _cn)) : point_barycentric)
  : bool =
  in_range a 0 factor && in_range b 0 factor && in_range c 0 factor

fun interpolate_z
  (triangle : triangle_projected)
  ((_factor, (_a, _b, _c), (an, bn, cn)) : point_barycentric)
  : f32 =
  let ((_xp0, _yp0, z0), (_xp1, _yp1, z1), (_xp2, _yp2, z2)) = triangle
  in an * z0 + bn * z1 + cn * z2

fun render_triangle
  (camera : camera)
  (triangle : triangle)
  (frame : *[w][h]pixel)
  : [w][h]pixel =
  let ((x0, y0, z0), (x1, y1, z1), (x2, y2, z2)) = triangle
  let (xp0, yp0) = project_point camera (x0, y0, z0)
  let (xp1, yp1) = project_point camera (x1, y1, z1)
  let (xp2, yp2) = project_point camera (x2, y2, z2)
  let triangle_projected = ((xp0, yp0, z0), (xp1, yp1, z1), (xp2, yp2, z2))

  let x_min = bound w (I32.min3 xp0 xp1 xp2)
  let x_max = bound w (I32.max3 xp0 xp1 xp2)
  let y_min = bound h (I32.min3 yp0 yp1 yp2)
  let y_max = bound h (I32.max3 yp0 yp1 yp2)
  let x_diff = x_max - x_min
  let y_diff = y_max - y_min
  let x_range = map (+ x_min) (iota x_diff)
  let y_range = map (+ y_min) (iota y_diff)

  let bbox_coordinates =
    reshape (x_diff * y_diff)
    (map (fn (x : i32) : [](i32, i32) =>
            map (fn (y : i32) : (i32, i32) =>
                   (x, y))
                y_range)
         x_range)
  let bbox_indices =
    map (fn ((x, y) : (i32, i32)) : i32 =>
           x * h + y)
        bbox_coordinates

  let barys = map (barycentric_coordinates triangle_projected)
                  bbox_coordinates
  let mask = map is_inside_triangle barys
  let z_values = map (interpolate_z triangle_projected)
                     barys

  let (write_indices, write_values) =
    unzip (zipWith (fn (index : i32)
                       (inside : bool)
                       (z : f32)
                       : (i32, pixel) =>
                      if inside
                      then let h = 120.0
                           let s = 0.8
                           let v = 1.0 - z
                           let rgb = hsv_to_rgb (h, s, v)
                           let pixel = rgb_to_pixel rgb
                           in (index, pixel)
                      else (-1, 0u32))
                   bbox_indices mask z_values)
  let pixels = reshape (w * h) frame
  let pixels' = write write_indices write_values pixels
  let frame' = reshape (w, h) pixels'
  in frame'

entry test
  (
   f : *[w][h]pixel,
   x0 : f32, y0 : f32, z0 : f32,
   x1 : f32, y1 : f32, z1 : f32,
   x2 : f32, y2 : f32, z2 : f32
  ) : [w][h]pixel =
  let t = ((x0, y0, z0), (x1, y1, z1), (x2, y2, z2))
  let c = ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
  in render_triangle c t f
