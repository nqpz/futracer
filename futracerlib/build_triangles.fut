import "render_types"

import "lib/github.com/diku-dk/segmented/segmented"

-- All of this is heavily copied from Martin Elsman's
-- https://github.com/melsman/canvas demo.

let bubble (a: point_projected) (b: point_projected): (point_projected, point_projected) =
  if b.y < a.y then (b, a) else (a, b)

let normalize ((p, q, r): triangle_projected): triangle_projected =
  let (p, q) = bubble p q
  let (q, r) = bubble q r
  let (p, q) = bubble p q
  in (p, q, r)

let lines_in_triangle (((p, _, r), _): (triangle_projected, i64)): i64 =
  i64.i32 (r.y - p.y + 1)

let dxdy (a: point_projected) (b: point_projected): f32 =
  let dx = b.x - a.x
  let dy = b.y - a.y
  in if dy == 0 then f32.i32 0
     else f32.i32 dx f32./ f32.i32 dy

let get_line_in_triangle (((p, q, r), ix): (triangle_projected, i64)) (i: i64): (line, i64) =
  let i = i32.i64 i
  let y = p.y + i
  in if i <= q.y - p.y then     -- upper half
     let sl1 = dxdy p q
     let sl2 = dxdy p r
     let x1 = p.x + i32.f32 (sl1 * f32.i32 i)
     let x2 = p.x + i32.f32 (sl2 * f32.i32 i)
     in (({x=x1, y}, {x=x2,y}), ix)
     else                       -- lower half
     let sl1 = dxdy r p
     let sl2 = dxdy r q
     let dy = (r.y - p.y) - i
     let x1 = r.x - i32.f32 (sl1 * f32.i32 dy)
     let x2 = r.x - i32.f32 (sl2 * f32.i32 dy)
     in (({x=x1, y}, {x=x2, y}), ix)

let lines_of_triangles [tn] (triangles: [tn]triangle_projected): [](line, i64) =
  let triangles' = map normalize triangles
  in expand lines_in_triangle get_line_in_triangle
            (zip triangles' (0..<tn))

let swap ({x, y}: point): point = {x=y, y=x}

let compare (v1: i32) (v2: i32): i32 =
  if v2 > v1 then 1 else if v1 > v2 then -1 else 0

let slo ({x=x1, y=y1}: point) ({x=x2, y=y2}: point): f32 =
  if x2 == x1 then if y2 > y1 then r32 1 else r32 (-1)
  else r32 (y2 - y1) / r32 (i32.abs (x2 - x1))

let points_in_line ((({x=x1, y=y1}, {x=x2, y=y2}), _): (line, i64)): i64 =
  i64.i32 (i32.(1 + max (abs (x2 - x1)) (abs (y2 - y1))))

let get_point_in_line (((p1, p2), ix): (line, i64)) (i: i64): (point, i64) =
  let i = i32.i64 i in
  if i32.abs (p1.x - p2.x) > i32.abs (p1.y - p2.y)
  then let dir = compare p1.x p2.x
       let sl = slo p1 p2
       in ({x=p1.x + dir * i,
            y=p1.y + t32 (sl * r32 i)}, ix)
  else let dir = compare (p1.y) (p2.y)
       let sl = slo (swap p1) (swap p2)
       in ({x=p1.x + t32 (sl * r32 i),
            y=p1.y + i * dir}, ix)

let points_of_lines (lines: [](line, i64)): [](point, i64) =
  expand points_in_line get_point_in_line lines
