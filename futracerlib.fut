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
type camera = (F32.D3.point, F32.D3.angles)
type pixel = u32
type pixel_channel = u32
type rgb = (pixel_channel, pixel_channel, pixel_channel)
type hsv = (f32, f32, f32)

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

fun hsv_to_rgb (h : f32, s : f32, v : f32) : rgb =
  let c = v * s
  let h' = h / 60.0
  let x = c * (1.0 - F32.abso (F32.mod h' 2.0 - 1.0))
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

fun normalize_point
  (((xc, yc, zc), (ax, ay, az)) : camera)
  (p0 : F32.D3.point)
  : F32.D3.point =
  let p1 = (translate_point (-xc, -yc, -zc) p0)
  let p2 = rotate_point (-ax, -ay, -az) (0.0, 0.0, 0.0) p1
  in p2

fun normalize_triangle
  (camera : camera)
  ((p0, p1, p2) : triangle)
  : triangle =
  let p0n = normalize_point camera p0
  let p1n = normalize_point camera p1
  let p2n = normalize_point camera p2
  let triangle' = (p0n, p1n, p2n)
  in triangle'

fun project_point
  (w : i32) (h : i32)
  ((x, y, z) : F32.D3.point)
  : I32.D2.point =
  let view_dist = 600.0
  let z_ratio = (view_dist + z) / view_dist

  let x_projected = x / z_ratio + f32 w / 2.0
  let y_projected = y / z_ratio + f32 h / 2.0

  in (i32 x_projected, i32 y_projected)

fun project_triangle
  (w : i32) (h : i32)
  (triangle : triangle)
  : triangle_projected =
  let ((x0, y0, z0), (x1, y1, z1), (x2, y2, z2)) = triangle
  let (xp0, yp0) = project_point w h (x0, y0, z0)
  let (xp1, yp1) = project_point w h (x1, y1, z1)
  let (xp2, yp2) = project_point w h (x2, y2, z2)
  let triangle_projected = ((xp0, yp0, z0), (xp1, yp1, z1), (xp2, yp2, z2))
  in triangle_projected

fun in_range (t : i32) (a : i32) (b : i32) : bool =
  (a < b && a <= t && t <= b) || (b <= a && b <= t && t <= a)

fun barycentric_coordinates
  ((x, y) : I32.D2.point)
  (triangle : triangle_projected)
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

fun hsv_average
  ((h0, s0, v0) : hsv)
  ((h1, s1, v1) : hsv)
  : hsv =
  let (h0, h1) = if h0 < h1 then (h0, h1) else (h1, h0)
  let diff_a = h1 - h0
  let diff_b = h0 + 360.0 - h1
  let h = if diff_a < diff_b
          then h0 + diff_a / 2.0
          else F32.mod (h1 + diff_b / 2.0) 360.0
  let s = (s0 + s1) / 2.0
  let v = (v0 + v1) / 2.0
  in (h, s, v)

fun render_triangles
  (camera : camera)
  (triangles : [tn]triangle)
  (frame : *[w][h]pixel)
  : [w][h]pixel =

  let bbox_coordinates =
    reshape (w * h)
    (map (fn (x : i32) : [](i32, i32) =>
            map (fn (y : i32) : (i32, i32) =>
                   (x, y))
                (iota h))
         (iota w))
  let bbox_indices =
    map (fn ((x, y) : (i32, i32)) : i32 =>
           x * h + y)
        bbox_coordinates

  let triangles_normalized = map (normalize_triangle camera)
                                 triangles

  let triangles_projected = map (project_triangle w h)
                                triangles_normalized

  let baryss = map (fn (p : I32.D2.point) : [tn]point_barycentric =>
                      map (barycentric_coordinates p)
                          triangles_projected)
                   bbox_coordinates

  let is_insidess = map (fn (barys : [tn]point_barycentric) : [tn]bool =>
                           map is_inside_triangle barys)
                       baryss

  let z_valuess = map (fn (barys : [tn]point_barycentric) : [tn]f32 =>
                         zipWith interpolate_z triangles_projected barys)
                      baryss

  let colorss = map (fn (z_values : []f32) : [tn]hsv =>
                       map (fn (z : f32) : hsv =>
                              let h = 120.0
                              let s = 0.8
                              let v = F32.min 1.0 (1.0 / (z * 0.01))
                              in (h, s, v))
                           z_values)
                    z_valuess

  let (mask, _z_values, colors) =
    unzip (zipWith (fn (is_insides : [tn]bool)
                       (z_values : [tn]f32)
                       (colors : [tn]hsv)
                       : (bool, f32, hsv) =>
                      let neutral_element = (False, -1.0, (0.0, 0.0, 0.0)) in
                      (reduce (fn ((in_triangle0, z0, hsv0)
                                   : (bool, f32, hsv))
                                  ((in_triangle1, z1, hsv1)
                                   : (bool, f32, hsv))
                                  : (bool, f32, hsv) =>
                                 if (in_triangle0 && z0 >= 0.0 &&
                                     (z1 < 0.0 || !in_triangle1 || z0 < z1))
                                 then (True, z0, hsv0)
                                 else if (in_triangle1 && z1 >= 0.0 &&
                                          (z0 < 0.0 || !in_triangle0 || z1 < z0))
                                 then (True, z1, hsv1)
                                 else if (in_triangle0 && z0 > 0.0 &&
                                          in_triangle1 && z1 > 0.0 && z0 == z1)
                                 then (True, z0, hsv_average hsv0 hsv1)
                                 else neutral_element)
                              neutral_element
                              (zip is_insides z_values colors)))
                   is_insidess z_valuess colorss)

  let pixels = map (fn x => rgb_to_pixel (hsv_to_rgb x)) colors

  let (write_indices, write_values) =
    unzip (zipWith (fn (index : i32)
                       (pixel : pixel)
                       (inside : bool)
                       : (i32, pixel) =>
                      if inside
                      then (index, pixel)
                      else (-1, 0u32))
                   bbox_indices pixels mask)

  let pixels = reshape (w * h) frame
  let pixels' = write write_indices write_values pixels
  let frame' = reshape (w, h) pixels'
  in frame'

entry render_triangles_raw
  (
   frame : *[w][h]pixel,
   x0s : [n]f32,
   y0s : [n]f32,
   z0s : [n]f32,
   x1s : [n]f32,
   y1s : [n]f32,
   z1s : [n]f32,
   x2s : [n]f32,
   y2s : [n]f32,
   z2s : [n]f32,
   c_x : f32,
   c_y : f32,
   c_z : f32,
   c_ax : f32,
   c_ay : f32,
   c_az : f32
  ) : [w][h]pixel =
  let camera = ((c_x, c_y, c_z), (c_ax, c_ay, c_az))
  let p0s = zip x0s y0s z0s
  let p1s = zip x1s y1s z1s
  let p2s = zip x2s y2s z2s
  let triangles = zip p0s p1s p2s
  in render_triangles camera triangles frame

fun rotate_point
  ((angle_x, angle_y, angle_z) : F32.D3.angles)
  ((x_origo, y_origo, z_origo) : F32.D3.point)
  ((x, y, z) : F32.D3.point)
  : F32.D3.point =
  let (x0, y0, z0) = (x - x_origo, y - y_origo, z - z_origo)

  let (sin_x, cos_x) = (sin32 angle_x, cos32 angle_x)
  let (sin_y, cos_y) = (sin32 angle_y, cos32 angle_y)
  let (sin_z, cos_z) = (sin32 angle_z, cos32 angle_z)

  -- X axis.
  let (x1, y1, z1) = (x0,
                      y0 * cos_x - z0 * sin_x,
                      y0 * sin_x + z0 * cos_x)
  -- Y axis.
  let (x2, y2, z2) = (z1 * sin_y + x1 * cos_y,
                      y1,
                      z1 * cos_y - x1 * sin_y)
  -- Z axis.
  let (x3, y3, z3) = (x2 * cos_z - y2 * sin_z,
                      x2 * sin_z + y2 * cos_z,
                      z2)

  let (x', y', z') = (x_origo + x3, y_origo + y3, z_origo + z3)
  in (x', y', z')

entry rotate_point_raw
  (angle_x : f32, angle_y : f32, angle_z : f32,
   x_origo : f32, y_origo : f32, z_origo : f32,
   x : f32, y : f32, z : f32) : (f32, f32, f32) =
  rotate_point (angle_x, angle_y, angle_z) (x_origo, y_origo, z_origo) (x, y, z)

fun translate_point
  ((x_move, y_move, z_move) : F32.D3.point)
  ((x, y, z) : F32.D3.point)
  : F32.D3.point =
  (x + x_move, y + y_move, z + z_move)

entry translate_point_raw
  (x_move : f32, y_move : f32, z_move : f32,
   x : f32, y : f32, z : f32) : (f32, f32, f32) =
  translate_point (x_move, y_move, z_move) (x, y, z)
