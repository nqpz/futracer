import "futracerlib/color"
import "futracerlib/transformations"
import "futracerlib/render_types"
import "futracerlib/render"

entry rotate_point_raw
  (angle_x: f32) (angle_y: f32) (angle_z: f32)
  (x_origo: f32) (y_origo: f32) (z_origo: f32)
  (x: f32) (y: f32) (z: f32): (f32, f32, f32) =
  let {x, y, z} = rotate_point {x=angle_x, y=angle_y, z=angle_z}
                               {x=x_origo, y=y_origo, z=z_origo}
                               {x=x, y=y, z=z}
  in (x, y, z)

entry translate_point_raw
  (x_move: f32) (y_move: f32) (z_move: f32)
  (x: f32) (y: f32) (z: f32): (f32, f32, f32) =
  let {x, y, z} = translate_point {x=x_move, y=y_move, z=z_move}
                                  {x=x, y=y, z=z}
  in (x, y, z)

entry render_triangles_raw
  [n]
  (render_approach: render_approach_id)
  (n_draw_rects_x: i32)
  (n_draw_rects_y: i32)
  (w: i64)
  (h: i64)
  (view_dist: f32)
  (draw_dist: f32)
  (x0s: [n]f32)
  (y0s: [n]f32)
  (z0s: [n]f32)
  (x1s: [n]f32)
  (y1s: [n]f32)
  (z1s: [n]f32)
  (x2s: [n]f32)
  (y2s: [n]f32)
  (z2s: [n]f32)
  (surface_types: [n]surface_type)
  (surface_hsv_hs: [n]f32)
  (surface_hsv_ss: [n]f32)
  (surface_hsv_vs: [n]f32)
  (surface_indices: [n]i32)
  (surface_n: i64)
  (surface_w: i64)
  (surface_h: i64)
  (surface_textures_flat_hsv_hs: []f32)
  (surface_textures_flat_hsv_ss: []f32)
  (surface_textures_flat_hsv_vs: []f32)
  (c_x: f32)
  (c_y: f32)
  (c_z: f32)
  (c_ax: f32)
  (c_ay: f32)
  (c_az: f32): [w][h]pixel =
  let n_draw_rects = (n_draw_rects_x, n_draw_rects_y)
  let camera = ({x=c_x, y=c_y, z=c_z}, {x=c_ax, y=c_ay, z=c_az})
  let p0s = map3 (\x y z -> {x=x, y=y, z=z}) x0s y0s z0s
  let p1s = map3 (\x y z -> {x=x, y=y, z=z}) x1s y1s z1s
  let p2s = map3 (\x y z -> {x=x, y=y, z=z}) x2s y2s z2s
  let triangles = zip3 p0s p1s p2s
  let surface_hsvs = zip3 surface_hsv_hs surface_hsv_ss surface_hsv_vs
  let surfaces = zip3 surface_types surface_hsvs surface_indices
  let surface_textures = unflatten_3d surface_n surface_h surface_w
                                      (zip3 surface_textures_flat_hsv_hs
                                            surface_textures_flat_hsv_ss
                                            surface_textures_flat_hsv_vs)
  let triangles_with_surfaces = zip triangles surfaces
  in render_triangles_in_view render_approach n_draw_rects
                              camera triangles_with_surfaces
                              surface_textures w h view_dist draw_dist
