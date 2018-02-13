import "/futlib/math"
import "/futlib/colour"

import "futracerlib/color"
import "futracerlib/transformations"
import "futracerlib/render"

default (i32, f32)

entry rotate_point_raw
  (angle_x: f32, angle_y: f32, angle_z: f32,
   x_origo: f32, y_origo: f32, z_origo: f32,
   x: f32, y: f32, z: f32): (f32, f32, f32) =
  rotate_point (angle_x, angle_y, angle_z) (x_origo, y_origo, z_origo) (x, y, z)

entry translate_point_raw
  (x_move: f32, y_move: f32, z_move: f32,
   x: f32, y: f32, z: f32): (f32, f32, f32) =
  translate_point (x_move, y_move, z_move) (x, y, z)

entry render_triangles_raw
  [n]
  (
   render_approach: render_approach_id,
   n_draw_rects_x: i32,
   n_draw_rects_y: i32,
   w: i32,
   h: i32,
   view_dist: f32,
   draw_dist: f32,
   x0s: [n]f32,
   y0s: [n]f32,
   z0s: [n]f32,
   x1s: [n]f32,
   y1s: [n]f32,
   z1s: [n]f32,
   x2s: [n]f32,
   y2s: [n]f32,
   z2s: [n]f32,
   surface_types: [n]surface_type,
   surface_hsv_hs: [n]f32,
   surface_hsv_ss: [n]f32,
   surface_hsv_vs: [n]f32,
   surface_indices: [n]i32,
   surface_n: i32,
   surface_w: i32,
   surface_h: i32,
   surface_textures_flat_hsv_hs: []f32,
   surface_textures_flat_hsv_ss: []f32,
   surface_textures_flat_hsv_vs: []f32,
   c_x: f32,
   c_y: f32,
   c_z: f32,
   c_ax: f32,
   c_ay: f32,
   c_az: f32
  ): [w][h][3]u8 =
  let n_draw_rects = (n_draw_rects_x, n_draw_rects_y)
  let camera = ((c_x, c_y, c_z), (c_ax, c_ay, c_az))
  let p0s = zip x0s y0s z0s
  let p1s = zip x1s y1s z1s
  let p2s = zip x2s y2s z2s
  let triangles = zip p0s p1s p2s
  let surface_hsvs = zip surface_hsv_hs surface_hsv_ss surface_hsv_vs
  let surfaces = zip surface_types surface_hsvs surface_indices
  let surface_textures = reshape (surface_n, surface_h, surface_w)
                                 (zip surface_textures_flat_hsv_hs
                                      surface_textures_flat_hsv_ss
                                      surface_textures_flat_hsv_vs)
  let triangles_with_surfaces = zip triangles surfaces
  let pixels = render_triangles_in_view render_approach n_draw_rects
                                        camera triangles_with_surfaces
                                        surface_textures w h view_dist draw_dist
  in argb.to_screen (map (\r -> map i32.u32 r) pixels)
