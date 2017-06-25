import "/futlib/math"

import "futracerlib/misc"
import "futracerlib/color"
import "futracerlib/transformations"

default (i32, f32)

type render_approach_id = i32

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
    let x_projected = x / z_ratio + f32 w / 2.0
    let y_projected = y / z_ratio + f32 h / 2.0
    in (i32 x_projected, i32 y_projected)

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
          let factor' = f32 factor
          let an = f32 a / factor'
          let bn = f32 b / factor'
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
  (surface_textures: [][#texture_h][#texture_w]hsv)
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
         let (an, bn, cn) = #3 bary
         let yn = an * yn0 + bn * yn1 + cn * yn2
         let xn = an * xn0 + bn * xn1 + cn * xn2
         let yi = i32 (yn * f32 texture_h)
         let xi = i32 (xn * f32 texture_w)
         let yi' = clamp yi 0 (texture_h - 1)
         let xi' = clamp xi 0 (texture_w - 1)
         in unsafe double_tex[yi', xi']
    else (0.0, 0.0, 0.0) -- unsupported input
  let flashlight_brightness = 2.0 * 10.0**5.0
  let v_factor = f32.min 1.0 (flashlight_brightness
                              / (z ** 2.0))
  in (h, s, v * v_factor)

let render_triangles_redomap
  (triangles_projected: [#tn]triangle_projected)
  (surfaces: [#tn]surface)
  (surface_textures: [][#texture_h][#texture_w]hsv)
  (w: i32) (h: i32)
  : [w][h]pixel =
  let coordinates =
    reshape (w * h)
    (map (\(x: i32): [h](i32, i32) ->
            map (\(y: i32): (i32, i32) ->
                   (x, y))
                (iota h))
         (iota w))

  let baryss = map (\(p: i32racer.point2D): [tn]point_barycentric ->
                      map (barycentric_coordinates p)
                          triangles_projected)
                   coordinates

  let is_insidess = map (\(barys: [tn]point_barycentric): [tn]bool ->
                           map is_inside_triangle barys)
                        baryss

  let z_valuess = map (\(barys: [tn]point_barycentric): [tn]f32 ->
                         map interpolate_z triangles_projected barys)
                      baryss

  let colorss = map (\(z_values: [tn]f32)
                      (barys: [tn]point_barycentric): [tn]hsv ->
                       map (color_point surface_textures)
                           surfaces z_values barys)
                    z_valuess baryss

  let (_mask, _z_values, colors) =
    unzip (map (\(is_insides: [tn]bool)
                 (z_values: [tn]f32)
                 (colors: [tn]hsv)
                 : (bool, f32, hsv) ->
                  let neutral_element = (false, -1.0, (0.0, 0.0, 0.0)) in
                  (reduce_comm (\((in_triangle0, z0, hsv0)
                                : (bool, f32, hsv))
                                ((in_triangle1, z1, hsv1)
                                : (bool, f32, hsv))
                               : (bool, f32, hsv) ->
                                 if (in_triangle0 && z0 >= 0.0 &&
                                     (z1 < 0.0 || !in_triangle1 || z0 < z1))
                                 then (true, z0, hsv0)
                                 else if (in_triangle1 && z1 >= 0.0 &&
                                          (z0 < 0.0 || !in_triangle0 || z1 < z0))
                                 then (true, z1, hsv1)
                                 else if (in_triangle0 && z0 >= 0.0 &&
                                          in_triangle1 && z1 >= 0.0 && z0 == z1)
                                 then (true, z0, hsv_average hsv0 hsv1)
                                 else neutral_element)
                              neutral_element
                              (zip is_insides z_values colors)))
               is_insidess z_valuess colorss)

  let pixels = map (\x -> rgb_to_pixel (hsv_to_rgb x)) colors
  let frame = reshape (w, h) pixels
  in frame

let render_triangles_scatter_bbox
  (triangles_projected: [#tn]triangle_projected)
  (surfaces: [#tn]surface)
  (surface_textures: [][#texture_h][#texture_w]hsv)
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
    loop ((pixels, z_values) = (pixels_initial, z_values_initial))
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

    let colors_new = map (color_point surface_textures surface)
                         z_values_new barys_new
    let pixels_new = map (\x -> rgb_to_pixel (hsv_to_rgb x)) colors_new

    let is_insides_new = map is_inside_triangle barys_new

    let colors_merged = map merge_colors indices z_values_cur
                            pixels_new z_values_new is_insides_new
    let (indices_merged, pixels_merged, z_values_merged) = unzip colors_merged

    let pixels' = scatter pixels indices_merged pixels_merged
    let z_values' = scatter z_values indices_merged z_values_merged
    in (pixels', z_values')
  let frame' = reshape (w, h) pixels
  in frame'

let render_triangles_in_view
  (render_approach: render_approach_id)
  (camera: camera)
  (triangles_with_surfaces: []triangle_with_surface)
  (surface_textures: [][#texture_h][#texture_w]hsv)
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
    (close_enough_dist (#1 triangle) ||
     close_enough_dist (#2 triangle) ||
     close_enough_dist (#3 triangle)) &&
    !(close_enough_fully_out_of_frame triangle)

  let triangles_close = filter (\(t, _s) -> close_enough t)
                               (zip triangles_projected surfaces)
  let (triangles_projected', surfaces') = unzip triangles_close

  in if render_approach == 1
     then render_triangles_redomap triangles_projected' surfaces' surface_textures w h
     else if render_approach == 2
     then render_triangles_scatter_bbox triangles_projected' surfaces' surface_textures w h
     else replicate w (replicate h 0u32) -- error
