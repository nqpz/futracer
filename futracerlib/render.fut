import "/futlib/math"

import "/futracerlib/misc"
import "/futracerlib/color"
import "/futracerlib/transformations"

default (i32, f32)

type render_approach_id = i32

-- FIXME: Use records.
type triangle = (f32racer.point3D, f32racer.point3D, f32racer.point3D)
type point_projected = (i32, i32, f32)
type triangle_projected = (point_projected, point_projected, point_projected)
type point_barycentric = (i32, i32racer.point3D, f32racer.point3D)
type camera = (f32racer.point3D, f32racer.angles)
type rectangle = (i32racer.point2D, i32racer.point2D)

-- If surface_type == 1, use the color in #1 surface.
-- If surface_type == 2, use the surface from the index in #2 surface.
type surface_type = i32
type surface = (surface_type, hsv, i32)
-- A double texture contains two textures: one in the upper left triangle, and
-- one (backwards) in the lower right triangle.  Use `texture_index / 2` to
-- refer to the correct double texture.
type surface_double_texture = [][]hsv
type triangle_with_surface = (triangle, surface)

let normalize_triangle
  (((xc, yc, zc), (ax, ay, az)): camera)
  ((p0, p1, p2): triangle)
  : triangle =
  let normalize_point (pa: f32racer.point3D): f32racer.point3D =
    let pb = translate_point (-xc, -yc, -zc) pa
    let pc = rotate_point (-ax, -ay, -az) (0.0, 0.0, 0.0) pb
    in pc

  in (normalize_point p0,
      normalize_point p1,
      normalize_point p2)

let project_triangle
  (w: i32) (h: i32)
  (view_dist: f32)
  (triangle: triangle)
  : triangle_projected =

  let project_point
    ((x, y, z): f32racer.point3D)
    : i32racer.point2D =
    let z_ratio = if z >= 0.0
                  then (view_dist + z) / view_dist
                  else 1.0 / ((view_dist - z) / view_dist)
    let x_projected = x / z_ratio + r32 w / 2.0
    let y_projected = y / z_ratio + r32 h / 2.0
    in (t32 x_projected, t32 y_projected)

  let ((x0, y0, z0), (x1, y1, z1), (x2, y2, z2)) = triangle
  let (xp0, yp0) = project_point (x0, y0, z0)
  let (xp1, yp1) = project_point (x1, y1, z1)
  let (xp2, yp2) = project_point (x2, y2, z2)
  in ((xp0, yp0, z0), (xp1, yp1, z1), (xp2, yp2, z2))

let barycentric_coordinates
  ((x, y): i32racer.point2D)
  (triangle: triangle_projected)
  : point_barycentric =
  let ((xp0, yp0, _z0), (xp1, yp1, _z1), (xp2, yp2, _z2)) = triangle
  let factor = (yp1 - yp2) * (xp0 - xp2) + (xp2 - xp1) * (yp0 - yp2)
  in if factor != 0 -- Avoid division by zero.
     then let a = ((yp1 - yp2) * (x - xp2) + (xp2 - xp1) * (y - yp2))
          let b = ((yp2 - yp0) * (x - xp2) + (xp0 - xp2) * (y - yp2))
          let c = factor - a - b
          let factor' = r32 factor
          let an = r32 a / factor'
          let bn = r32 b / factor'
          let cn = 1.0 - an - bn
          in (factor, (a, b, c), (an, bn, cn))
     else (1, (-1, -1, -1), (-1.0, -1.0, -1.0)) -- Don't draw.

let is_inside_triangle
  ((factor, (a, b, c), (_an, _bn, _cn)): point_barycentric)
  : bool =
  in_range a 0 factor && in_range b 0 factor && in_range c 0 factor

let interpolate_z
  (triangle: triangle_projected)
  ((_factor, (_a, _b, _c), (an, bn, cn)): point_barycentric)
  : f32 =
  let ((_xp0, _yp0, z0), (_xp1, _yp1, z1), (_xp2, _yp2, z2)) = triangle
  in an * z0 + bn * z1 + cn * z2

let color_point
  [texture_h][texture_w]
  (surface_textures: [][texture_h][texture_w]hsv)
  ((s_t, s_hsv, s_ti): surface)
  (z: f32)
  (bary: point_barycentric)
  : hsv =
  let (h, s, v) =
    if s_t == 1
    -- Use the color.
    then s_hsv
    else if s_t == 2
    -- Use the texture index.
    then let double_tex = unsafe surface_textures[s_ti / 2]
         let ((xn0, yn0), (xn1, yn1), (xn2, yn2)) =
           if s_ti & 1 == 0
           then ((0.0, 0.0),
                 (0.0, 1.0),
                 (1.0, 0.0))
           else ((1.0, 1.0),
                 (1.0, 0.0),
                 (0.0, 1.0))
         -- FIXME: This results in a slightly distorted image, as it is based on
         -- the projected triangle, not the actual triangle.  This is fine for
         -- small triangles, but noticable for large triangles.
         let (an, bn, cn) = bary.3
         let yn = an * yn0 + bn * yn1 + cn * yn2
         let xn = an * xn0 + bn * xn1 + cn * xn2
         let yi = t32 (yn * r32 texture_h)
         let xi = t32 (xn * r32 texture_w)
         let yi' = clamp yi 0 (texture_h - 1)
         let xi' = clamp xi 0 (texture_w - 1)
         in unsafe double_tex[yi', xi']
    else (0.0, 0.0, 0.0) -- unsupported input
  let flashlight_brightness = 2.0 * 10.0**5.0
  let v_factor = f32.min 1.0 (flashlight_brightness
                              / (z ** 2.0))
  in (h, s, v * v_factor)

let render_triangles_chunked
  [tn][texture_h][texture_w]
  (triangles_projected: [tn]triangle_projected)
  (surfaces: [tn]surface)
  (surface_textures: [][texture_h][texture_w]hsv)
  (w: i32) (h: i32)
  ((n_rects_x, n_rects_y): (i32, i32))
  : [w][h]pixel =
  let each_pixel
    [rtpn]
    (rect_triangles_projected: [rtpn]triangle_projected)
    (rect_surfaces: []surface)
    (pixel_index: i32): pixel =
    let p = (pixel_index / h, pixel_index % h)
    let each_triangle
      (t: triangle_projected)
      (i: i32)
      : (bool, f32, i32) =
      let bary = barycentric_coordinates p t
      let in_triangle = is_inside_triangle bary
      let z = interpolate_z t bary
      in (in_triangle, z, i)

    let neutral_info = (false, -1.0, -1)
    let merge_colors
      ((in_triangle0, z0, i0): (bool, f32, i32))
      ((in_triangle1, z1, i1): (bool, f32, i32))
      : (bool, f32, i32) =
      if (in_triangle0 && z0 >= 0.0 &&
          (z1 < 0.0 || !in_triangle1 || z0 < z1))
      then (true, z0, i0)
      else if (in_triangle1 && z1 >= 0.0 &&
               (z0 < 0.0 || !in_triangle0 || z1 < z0))
      then (true, z1, i1)
      else if (in_triangle0 && z0 >= 0.0 &&
               in_triangle1 && z1 >= 0.0 && z0 == z1)
      then (true, z0, i0) -- Just pick one of them.
      else neutral_info

    let triangles_infos = map2 each_triangle rect_triangles_projected (0..<rtpn)
    let (_in_triangle, z, i) =
      reduce_comm merge_colors neutral_info triangles_infos
    let color = if i == -1
                then (0.0, 0.0, 0.0)
                else let bary = barycentric_coordinates p rect_triangles_projected[i]
                     in color_point surface_textures rect_surfaces[i] z bary

    in rgb_to_pixel (hsv_to_rgb color)

  let rect_in_rect
    (((x0a, y0a), (x1a, y1a)): rectangle)
    (((x0b, y0b), (x1b, y1b)): rectangle): bool =
    ! (x1a <= x0b || x0a >= x1b || y1a <= y0b || y0a >= y1b)

  let bounding_box
    (((x0, y0, _z0),
      (x1, y1, _z1),
      (x2, y2, _z2)): triangle_projected): rectangle =
    (((i32.min (i32.min x0 x1) x2),
      (i32.min (i32.min y0 y1) y2)),
     ((i32.max (i32.max x0 x1) x2),
      (i32.max (i32.max y0 y1) y2)))

  -- Does a triangle intersect with a rectangle?  FIXME: This might produce
  -- false positives (which is not a problem for the renderer, but could be more
  -- efficient).
  let triangle_in_rect
    (rect: rectangle)
    (tri: triangle_projected): bool =
    let rect1 = bounding_box tri
    in rect_in_rect rect1 rect || rect_in_rect rect rect1

  let each_rect
    [bn]
    (rect: rectangle)
    (pixel_indices: [bn]i32): [bn]pixel =
    let (rect_triangles_projected, rect_surfaces) =
      unsafe unzip (filter (\(t, _) -> triangle_in_rect rect t) (zip triangles_projected surfaces))
    in unsafe map (each_pixel rect_triangles_projected rect_surfaces) pixel_indices

  let rect_pixel_indices
    (((x0, y0), (x1, y1)): rectangle): []i32 =
    let (xlen, ylen) = (x1 - x0, y1 - y0)
    let xs = map (+ x0) (iota xlen)
    let ys = map (+ y0) (iota ylen)
    in reshape (xlen * ylen) (map (\x -> map (\y -> x * h + y) ys) xs)

  in if n_rects_x == 1 && n_rects_y == 1
     then -- Keep it simple.  This will be a redomap.
          let pixel_indices = iota (w * h)
          let pixels = unsafe map (each_pixel triangles_projected surfaces) pixel_indices
          in reshape (w, h) pixels
     else -- Split into rectangles, each with their own triangles, and use scatter
          -- in the end.
          let x_size = w / n_rects_x + i32.bool (w % n_rects_x > 0)
          let y_size = h / n_rects_y + i32.bool (h % n_rects_y > 0)
          let rects = reshape (n_rects_x * n_rects_y)
                              (map (\x -> map (\y ->
                                               let x0 = x * x_size
                                               let y0 = y * y_size
                                               let x1 = x0 + x_size
                                               let y1 = y0 + y_size
                                               in ((x0, y0), (x1, y1)))
                                    (iota n_rects_y)) (iota n_rects_x))
          let n_pixels = n_rects_x * n_rects_y * x_size * y_size

          let pixel_indicess = unsafe map rect_pixel_indices rects
          let pixelss = map2 each_rect rects pixel_indicess
          let pixel_indices = reshape n_pixels pixel_indicess
          let pixels = reshape n_pixels pixelss
          let pixel_indices' = map (\i -> if i < w * h then i else -1) pixel_indices
          let frame = replicate (w * h) 0u32
          let frame' = scatter frame pixel_indices' pixels
          in reshape (w, h) frame'

let render_triangles_scatter_bbox
  [tn][texture_w][texture_h]
  (triangles_projected: [tn]triangle_projected)
  (surfaces: [tn]surface)
  (surface_textures: [][texture_h][texture_w]hsv)
  (w: i32) (h: i32)
  : [w][h]pixel =
  let bounding_box
    (((x0, y0, _z0), (x1, y1, _z1), (x2, y2, _z2)): triangle_projected)
    : rectangle =
    ((within_bounds 0i32 (w - 1) (i32.min (i32.min x0 x1) x2),
      within_bounds 0i32 (h - 1) (i32.min (i32.min y0 y1) y2)),
     (within_bounds 0i32 (w - 1) (i32.max (i32.max x0 x1) x2),
      within_bounds 0i32 (h - 1) (i32.max (i32.max y0 y1) y2)))

  let merge_colors
    (i: i32)
    (z_cur: f32)
    (p_new: pixel)
    (z_new: f32)
    (in_triangle_new: bool)
    : (i32, pixel, f32) =
    if in_triangle_new && z_new >= 0.0 && (z_cur < 0.0 || z_new < z_cur)
    then (i, p_new, z_new)
    else (-1, 0u32, 0.0f32)

  let pixels_initial = replicate (w * h) 0u32
  let z_values_initial = replicate (w * h) f32.inf
  let (pixels, _z_values) =
    loop (pixels, z_values) = (pixels_initial, z_values_initial)
    for i < tn do
    let triangle_projected = triangles_projected[i]
    let surface = surfaces[i]

    let ((x_left, y_top), (x_right, y_bottom)) =
      bounding_box triangle_projected
    let x_span = x_right - x_left + 1
    let y_span = y_bottom - y_top + 1
    let coordinates = reshape (x_span * y_span)
                              (map (\x -> map (\y -> (x, y))
                                              (map (+ y_top) (iota y_span)))
                                   (map (+ x_left) (iota x_span)))
    let indices = map (\(x, y) -> x * h + y) coordinates

    let z_values_cur = map (\i -> unsafe z_values[i]) indices

    let barys_new = map (\(p: i32racer.point2D): point_barycentric ->
                           barycentric_coordinates p triangle_projected)
                        coordinates

    let z_values_new = map (interpolate_z triangle_projected) barys_new

    let colors_new = map2 (color_point surface_textures surface)
                          z_values_new barys_new
    let pixels_new = map (\x -> rgb_to_pixel (hsv_to_rgb x)) colors_new

    let is_insides_new = map is_inside_triangle barys_new

    let colors_merged = map5 merge_colors indices z_values_cur
                             pixels_new z_values_new is_insides_new
    let (indices_merged, pixels_merged, z_values_merged) = unzip colors_merged

    let pixels' = scatter pixels indices_merged pixels_merged
    let z_values' = scatter z_values indices_merged z_values_merged
    in (pixels', z_values')
  let frame' = reshape (w, h) pixels
  in frame'

let render_triangles_in_view
  [texture_h][texture_w]
  (render_approach: render_approach_id)
  (n_draw_rects: (i32, i32))
  (camera: camera)
  (triangles_with_surfaces: []triangle_with_surface)
  (surface_textures: [][texture_h][texture_w]hsv)
  (w: i32) (h: i32)
  (view_dist: f32)
  (draw_dist: f32)
  : [w][h]pixel =
  let (triangles, surfaces) = unzip triangles_with_surfaces
  let triangles_normalized = map (normalize_triangle camera)
                                 triangles
  let triangles_projected = map (project_triangle w h view_dist)
                                triangles_normalized

  let close_enough_dist ((_x, _y, z): point_projected): bool =
    0.0 <= z && z < draw_dist

  let close_enough_fully_out_of_frame
    (((x0, y0, _z0), (x1, y1, _z1), (x2, y2, _z2)): triangle_projected): bool =
    (x0 < 0 && x1 < 0 && x2 < 0) || (x0 >= w && x1 >= w && x2 >= w) ||
    (y0 < 0 && y1 < 0 && y2 < 0) || (y0 >= h && y1 >= h && y2 >= h)

  let close_enough (triangle: triangle_projected): bool =
    (close_enough_dist triangle.1 ||
     close_enough_dist triangle.2 ||
     close_enough_dist triangle.3) &&
    !(close_enough_fully_out_of_frame triangle)

  let triangles_close = filter (\(t, _s) -> close_enough t)
                               (zip triangles_projected surfaces)
  let (triangles_projected', surfaces') = unzip triangles_close

  in if render_approach == 1
     then render_triangles_chunked triangles_projected' surfaces'
                                   surface_textures w h n_draw_rects
     else if render_approach == 2
     then render_triangles_scatter_bbox triangles_projected' surfaces' surface_textures w h
     else replicate w (replicate h 0u32) -- error
