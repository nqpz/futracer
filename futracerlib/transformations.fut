include futracerlib.base.F32

default (i32, f32)

fun rotate_point
  ((angle_x, angle_y, angle_z) : F32.angles)
  ((x_origo, y_origo, z_origo) : F32.point3D)
  ((x, y, z) : F32.point3D)
  : F32.point3D =
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

fun translate_point
  ((x_move, y_move, z_move) : F32.point3D)
  ((x, y, z) : F32.point3D)
  : F32.point3D =
  (x + x_move, y + y_move, z + z_move)

entry rotate_point_raw
  (angle_x : f32, angle_y : f32, angle_z : f32,
   x_origo : f32, y_origo : f32, z_origo : f32,
   x : f32, y : f32, z : f32) : (f32, f32, f32) =
  rotate_point (angle_x, angle_y, angle_z) (x_origo, y_origo, z_origo) (x, y, z)

entry translate_point_raw
  (x_move : f32, y_move : f32, z_move : f32,
   x : f32, y : f32, z : f32) : (f32, f32, f32) =
  translate_point (x_move, y_move, z_move) (x, y, z)
