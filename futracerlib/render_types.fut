import "misc"
import "color"

type render_approach_id = i32

type triangle = (f32racer.point3D, f32racer.point3D, f32racer.point3D)
type point_projected = {x: i32, y: i32, z: f32}
type point = i32racer.point2D
type line = (point, point)
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
