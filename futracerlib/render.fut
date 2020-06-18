import "misc"
import "color"
import "transformations"
import "render_types"
import "build_triangles"

let normalize_triangle
  ((c, a): camera)
  ((p0, p1, p2): triangle)
  : triangle =
  let normalize_point (pa: f32racer.point3D): f32racer.point3D =
    let pb = translate_point {x= -c.x, y= -c.y, z= -c.z} pa
    let pc = rotate_point {x= -a.x, y= -a.y, z= -a.z} {x=0.0, y=0.0, z=0.0} pb
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
    ({x, y, z}: f32racer.point3D)
    : i32racer.point2D =
    let z_ratio = if z >= 0.0
                  then (view_dist + z) / view_dist
                  else 1.0 / ((view_dist - z) / view_dist)
    let x_projected = x / z_ratio + r32 w / 2.0
    let y_projected = y / z_ratio + r32 h / 2.0
    in {x=t32 x_projected, y=t32 y_projected}

  let ({x=x0, y=y0, z=z0}, {x=x1, y=y1, z=z1}, {x=x2, y=y2, z=z2}) = triangle
  let {x=xp0, y=yp0} = project_point {x=x0, y=y0, z=z0}
  let {x=xp1, y=yp1} = project_point {x=x1, y=y1, z=z1}
  let {x=xp2, y=yp2} = project_point {x=x2, y=y2, z=z2}
  in ({x=xp0, y=yp0, z=z0}, {x=xp1, y=yp1, z=z1}, {x=xp2, y=yp2, z=z2})

let barycentric_coordinates
  ({x, y}: i32racer.point2D)
  (triangle: triangle_projected)
  : point_barycentric =
  let ({x=xp0, y=yp0, z=_}, {x=xp1, y=yp1, z=_}, {x=xp2, y=yp2, z=_}) = triangle
  let factor = (yp1 - yp2) * (xp0 - xp2) + (xp2 - xp1) * (yp0 - yp2)
  in if factor != 0 -- Avoid division by zero.
     then let a = ((yp1 - yp2) * (x - xp2) + (xp2 - xp1) * (y - yp2))
          let b = ((yp2 - yp0) * (x - xp2) + (xp0 - xp2) * (y - yp2))
          let c = factor - a - b
          let factor' = r32 factor
          let an = r32 a / factor'
          let bn = r32 b / factor'
          let cn = 1.0 - an - bn
          in (factor, {x=a, y=b, z=c}, {x=an, y=bn, z=cn})
     else (1, {x= -1, y= -1, z= -1}, {x= -1.0, y= -1.0, z= -1.0}) -- Don't draw.

let is_inside_triangle
  ((factor, {x=a, y=b, z=c}, _): point_barycentric)
  : bool =
  in_range a 0 factor && in_range b 0 factor && in_range c 0 factor

let interpolate_z
  (triangle: triangle_projected)
  ((_factor, _, {x=an, y=bn, z=cn}): point_barycentric)
  : f32 =
  let ({x=_, y=_, z=z0}, {x=_, y=_, z=z1}, {x=_, y=_, z=z2}) = triangle
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
    then let double_tex = #[unsafe] surface_textures[s_ti / 2]
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
         let {x=an, y=bn, z=cn} = bary.2
         let yn = an * yn0 + bn * yn1 + cn * yn2
         let xn = an * xn0 + bn * xn1 + cn * xn2
         let yi = t32 (yn * r32 texture_h)
         let xi = t32 (xn * r32 texture_w)
         let yi' = clamp yi 0 (texture_h - 1)
         let xi' = clamp xi 0 (texture_w - 1)
         in #[unsafe] double_tex[yi', xi']
    else (0.0, 0.0, 0.0) -- unsupported input
  let flashlight_brightness = 2.0 * 10.0**6.0
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
    let p = {x=pixel_index / h, y=pixel_index % h}
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
    (({x=x0a, y=y0a}, {x=x1a, y=y1a}): rectangle)
    (({x=x0b, y=y0b}, {x=x1b, y=y1b}): rectangle): bool =
    ! (x1a <= x0b || x0a >= x1b || y1a <= y0b || y0a >= y1b)

  let bounding_box
    (({x=x0, y=y0, z=_},
      {x=x1, y=y1, z=_},
      {x=x2, y=y2, z=_}): triangle_projected): rectangle =
    ({x=i32.min (i32.min x0 x1) x2,
      y=i32.min (i32.min y0 y1) y2},
     {x=i32.max (i32.max x0 x1) x2,
      y=i32.max (i32.max y0 y1) y2})

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
      #[unsafe] unzip (filter (\(t, _) -> triangle_in_rect rect t) (zip triangles_projected surfaces))
    in #[unsafe] map (each_pixel rect_triangles_projected rect_surfaces) pixel_indices

  let rect_pixel_indices (totallen: i32)
    (({x=x0, y=y0}, {x=x1, y=y1}): rectangle): [totallen]i32 =
    let (xlen, ylen) = (x1 - x0, y1 - y0)
    let xs = map (+ x0) (iota xlen)
    let ys = map (+ y0) (iota ylen)
    in flatten (map (\x -> map (\y -> x * h + y) ys) xs) :> [totallen]i32

  in if n_rects_x == 1 && n_rects_y == 1
     then
     -- Keep it simple.  This will be a redomap.
     let pixel_indices = iota (w * h)
     let pixels = #[unsafe] map (each_pixel triangles_projected surfaces) pixel_indices
     in unflatten w h pixels
     else
     -- Split into rectangles, each with their own triangles, and use scatter in
     -- the end.
     let x_size = w / n_rects_x + i32.bool (w % n_rects_x > 0)
     let y_size = h / n_rects_y + i32.bool (h % n_rects_y > 0)
     let n_total = n_rects_y * n_rects_x
     let rects = flatten (map (\x -> map (\y ->
                                            let x0 = x * x_size
                                            let y0 = y * y_size
                                            let x1 = x0 + x_size
                                            let y1 = y0 + y_size
                                            in ({x=x0, y=y0}, {x=x1, y=y1}))
                                         (iota n_rects_y)) (iota n_rects_x)) :> [n_total]rectangle

     let pixel_indicess = #[unsafe] map (rect_pixel_indices (x_size * y_size)) rects
     let pixelss = map2 each_rect rects pixel_indicess
     let pixel_indices = flatten pixel_indicess
     let n = length pixel_indices
     let pixels = flatten pixelss :> [n]u32
     let pixel_indices' = map (\i -> if i < w * h then i else -1) pixel_indices :> [n]i32
     let frame = replicate (w * h) 0u32
     let frame' = scatter frame pixel_indices' pixels
     in unflatten w h frame'

let render_triangles_scatter_bbox
  [tn][texture_w][texture_h]
  (triangles_projected: [tn]triangle_projected)
  (surfaces: [tn]surface)
  (surface_textures: [][texture_h][texture_w]hsv)
  (w: i32) (h: i32)
  : [w][h]pixel =
  let bounding_box
    (({x=x0, y=y0, z=_z0}, {x=x1, y=y1, z=_z1}, {x=x2, y=y2, z=_z2}): triangle_projected)
    : rectangle =
    ({x=within_bounds 0i32 (w - 1) (i32.min (i32.min x0 x1) x2),
      y=within_bounds 0i32 (h - 1) (i32.min (i32.min y0 y1) y2)},
     {x=within_bounds 0i32 (w - 1) (i32.max (i32.max x0 x1) x2),
      y=within_bounds 0i32 (h - 1) (i32.max (i32.max y0 y1) y2)})

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

    let ({x=x_left, y=y_top}, {x=x_right, y=y_bottom}) =
      bounding_box triangle_projected
    let x_span = x_right - x_left + 1
    let y_span = y_bottom - y_top + 1
    let coordinates = flatten (map (\x -> map (\y -> {x, y})
                                              (map (+ y_top) (iota y_span)))
                                   (map (+ x_left) (iota x_span)))
    let indices = map (\{x, y} -> x * h + y) coordinates

    let z_values_cur = map (\i -> #[unsafe] z_values[i]) indices

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
    let (indices_merged, pixels_merged, z_values_merged) = unzip3 colors_merged

    let pixels' = scatter pixels indices_merged pixels_merged
    let z_values' = scatter z_values indices_merged z_values_merged
    in (pixels', z_values')
  let frame' = unflatten w h pixels
  in frame'

let encode_loc_and_ix (loc: i32) (ix: i32): i64 =
  (i64.i32 loc << 32) | i64.i32 ix

let decode_loc_and_ix (code: i64): (i32, i32) =
  (i32.i64 (code >> 32), i32.i64 code)

let render_triangles_segmented
  [tn][texture_w][texture_h]
  (triangles_projected: [tn]triangle_projected)
  (surfaces: [tn]surface)
  (surface_textures: [][texture_h][texture_w]hsv)
  (w: i32) (h: i32)
  : [w][h]pixel =
  let lines = lines_of_triangles triangles_projected
  let points = points_of_lines lines
  let points' = filter (\({x, y}, _) -> x >= 0 && x < w && y >=0 && y < h) points
  let indices = map (\({x, y}, _) -> x * h + y) points'
  let points'' = map (\({x, y}, ix) -> encode_loc_and_ix (x * h + y) ix) points'
  let empty_code = encode_loc_and_ix (-1) (-1)

  let update (code_a: i64) (code_b: i64): i64 =
    let ((loca, ia), (locb, ib)) = (decode_loc_and_ix code_a,
                                    decode_loc_and_ix code_b)
    in if ia == -1
       then code_b
       else if ib == -1
       then code_a
       else let (pa, pb) = ({x=loca / h, y=loca % h}, {x=locb / h, y=locb % h})
            let (ta, tb) = #[unsafe] (triangles_projected[ia], triangles_projected[ib])
            let (bary_a, bary_b) = (barycentric_coordinates pa ta,
                                    barycentric_coordinates pb tb)
            let (z_a, z_b) = (interpolate_z ta bary_a, interpolate_z tb bary_b)
            in if z_a < z_b
               then code_a
               else code_b

  let pixel_color (code: i64): u32 =
    let (loc, i) = decode_loc_and_ix code
    let p = {x=loc / h, y=loc % h}
    in if i == -1
       then 0x00000000
       else
       let (t, s) = #[unsafe] (triangles_projected[i], surfaces[i])
       let bary = barycentric_coordinates p t
       let z = interpolate_z t bary
       in let color = color_point surface_textures s z bary
          in rgb_to_pixel (hsv_to_rgb color)

  let pixels = replicate (w * h) empty_code
  let pixels' = reduce_by_index pixels update empty_code indices points''
  let pixels'' = map pixel_color pixels'
  in unflatten w h pixels''

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

  let close_enough_dist ({x=_, y=_, z}: point_projected): bool =
    0.0 <= z && z < draw_dist

  let close_enough_fully_out_of_frame
    (({x=x0, y=y0, z=_z0}, {x=x1, y=y1, z=_z1}, {x=x2, y=y2, z=_z2}): triangle_projected): bool =
    (x0 < 0 && x1 < 0 && x2 < 0) || (x0 >= w && x1 >= w && x2 >= w) ||
    (y0 < 0 && y1 < 0 && y2 < 0) || (y0 >= h && y1 >= h && y2 >= h)

  let close_enough (triangle: triangle_projected): bool =
    (close_enough_dist triangle.0 ||
     close_enough_dist triangle.1 ||
     close_enough_dist triangle.2) &&
    !(close_enough_fully_out_of_frame triangle)

  let triangles_close = filter (close_enough <-< (.0))
                               (zip triangles_projected surfaces)
  let (triangles_projected', surfaces') = unzip triangles_close

  in if render_approach == 1
     then render_triangles_segmented triangles_projected' surfaces' surface_textures w h
     else if render_approach == 2
     then render_triangles_chunked triangles_projected' surfaces'
                                   surface_textures w h n_draw_rects
     else if render_approach == 3
     then render_triangles_scatter_bbox triangles_projected' surfaces' surface_textures w h
     else replicate w (replicate h 0u32) -- error
