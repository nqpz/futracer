import itertools
import colorsys

import numpy
import png
import pyopencl as cl
import pyopencl.array

import futracerlib


APPROACH_REDOMAP, APPROACH_SCATTER_BBOX = range(1, 3)

class FutRacer:
    def __init__(self):
        self.futhark = futracerlib.futracerlib()

    def rgb8_to_hsv(self, rgb8):
        r8, g8, b8 = rgb8
        f = 255.0
        r, g, b = r8 / f, g8 / f, b8 / f
        h1, s1, v1 = colorsys.rgb_to_hsv(r, g, b)
        h360 = h1 * 360.0
        return (h360, s1, v1)

    def translate_point(self, move, point):
        args = move + point
        return self.futhark.translate_point_raw(*args)

    def translate_triangle(self, angles, origo, triangle):
        return [self.translate_point(angles, origo, p)
                for p in triangle[:3]] + triangle[3:]

    def rotate_point(self, angles, origo, point):
        args = angles + origo + point
        return self.futhark.rotate_point_raw(*args)

    def rotate_triangle(self, angles, origo, triangle):
        return [self.rotate_point(angles, origo, p)
                for p in triangle[:3]] + triangle[3:]

    def to_device(self, xs, typ):
        # This is VERY brittle.  It must change whenever futhark-pyopencl
        # changes.
        xs_np = numpy.fromiter(xs, dtype=typ)
        xs_mem = cl.Buffer(self.futhark.ctx, cl.mem_flags.READ_WRITE,
                        numpy.long(numpy.int32(4) * xs_np.shape[0]))
        cl.enqueue_copy(self.futhark.queue, xs_mem, xs_np,
                        is_blocking=False)
        xs = cl.array.Array(self.futhark.queue, xs_np.shape, typ,
                            data=xs_mem)
        return xs

    def preprocess_triangles(self, triangles):
        p0s = [t[0] for t in triangles]
        p1s = [t[1] for t in triangles]
        p2s = [t[2] for t in triangles]
        ss = [t[3] for t in triangles]

        x0s = self.to_device((p[0] for p in p0s), 'float32')
        y0s = self.to_device((p[1] for p in p0s), 'float32')
        z0s = self.to_device((p[2] for p in p0s), 'float32')

        x1s = self.to_device((p[0] for p in p1s), 'float32')
        y1s = self.to_device((p[1] for p in p1s), 'float32')
        z1s = self.to_device((p[2] for p in p1s), 'float32')

        x2s = self.to_device((p[0] for p in p2s), 'float32')
        y2s = self.to_device((p[1] for p in p2s), 'float32')
        z2s = self.to_device((p[2] for p in p2s), 'float32')

        s_types = self.to_device((s[0] for s in ss), 'int32')
        s_hsv_hs = self.to_device((s[1][0] for s in ss), 'float32')
        s_hsv_ss = self.to_device((s[1][1] for s in ss), 'float32')
        s_hsv_vs = self.to_device((s[1][2] for s in ss), 'float32')
        s_indices = self.to_device((s[2] for s in ss), 'int32')

        return (x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
                s_types, s_hsv_hs, s_hsv_ss, s_hsv_vs, s_indices)

    def load_double_texture(self, path):
        texture_raw = png.Reader(filename=path)
        t_w, t_h, t_pixels, t_meta = texture_raw.asRGB8()
        n_channels = 3
        rgbs_1d = numpy.fromiter(itertools.chain(*t_pixels), dtype='uint8')
        rgbs_2d = numpy.reshape(rgbs_1d, (t_h * t_w, n_channels))
        hsvs_2d = numpy.fromiter(itertools.chain(*map(self.rgb8_to_hsv, rgbs_2d)), dtype='float32')
        hsvs_3d = numpy.reshape(hsvs_2d, (t_h, t_w, n_channels))
        return hsvs_3d

    def preprocess_textures(self, textures):
        if len(textures) == 0:
            # The values will not be used.
            texture_w = 0
            texture_h = 0
        else:
            # Assume all textures have the same size.  They must have!
            # Otherwise something will fail later on.
            t = textures[0]
            texture_h, texture_w, _channels = t.shape

        if len(textures) > 0:
            s_textures = numpy.array(textures)
            s_textures_hs = s_textures[:,:,:,0]
            s_textures_hs_flat = numpy.reshape(
                s_textures_hs,
                len(textures) * texture_h * texture_w)
            s_textures_hs_flat = self.to_device(s_textures_hs_flat, 'float32')
            s_textures_ss = s_textures[:,:,:,1]
            s_textures_ss_flat = numpy.reshape(
                s_textures_ss,
                len(textures) * texture_h * texture_w).astype('float32')
            s_textures_ss_flat = self.to_device(s_textures_ss_flat, 'float32')
            s_textures_vs = s_textures[:,:,:,2]
            s_textures_vs_flat = numpy.reshape(
                s_textures_vs,
                len(textures) * texture_h * texture_w).astype('float32')
            s_textures_vs_flat = self.to_device(s_textures_vs_flat, 'float32')
        else:
            s_textures_hs_flat = numpy.empty((0,))
            s_textures_ss_flat = numpy.empty((0,))
            s_textures_vs_flat = numpy.empty((0,))

        return (len(textures), texture_w, texture_h,
                s_textures_hs_flat, s_textures_ss_flat, s_textures_vs_flat)

    def render_triangles_preprocessed(self, size, view_dist, draw_dist, camera,
                                      triangles_pre, textures_pre,
                                      render_approach='redomap'):
        w, h = size

        ((c_x, c_y, c_z), (c_ax, c_ay, c_az)) = camera

        (x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
         s_types, s_hsv_hs, s_hsv_ss, s_hsv_vs, s_indices) = triangles_pre

        (textures_len, texture_w, texture_h,
         s_textures_hs_flat, s_textures_ss_flat, s_textures_vs_flat) = textures_pre

        if render_approach == 'redomap':
            render_approach = APPROACH_REDOMAP
        elif render_approach == 'scatter_bbox':
            render_approach = APPROACH_SCATTER_BBOX

        return self.futhark.render_triangles_raw(
            render_approach, w, h, view_dist, draw_dist,
            x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
            s_types, s_hsv_hs, s_hsv_ss, s_hsv_vs, s_indices,
            textures_len, texture_w, texture_h,
            s_textures_hs_flat, s_textures_ss_flat, s_textures_vs_flat,
            c_x, c_y, c_z, c_ax, c_ay, c_az)

    def render_triangles(self, size, view_dist, draw_dist, camera,
                         triangles, triangles_pre,
                         textures, textures_pre,
                         render_approach='redomap'):
        if triangles is None:
            triangles_pre1 = triangles_pre
        else:
            triangles_pre0 = self.preprocess_triangles(triangles)
            triangles_pre1 = [pyopencl.array.concatenate((x, y))
                              for x, y in zip(triangles_pre0, triangles_pre)]
        if textures is None:
            textures_pre1 = textures_pre
        else:
            textures_pre0 = self.preprocess_triangles(textures)
            p0_length, p0_w, p0_h = textures_pre0[:3]
            p_length, p_w, p_h = textures_pre0[:3]
            length = p0_length + p_length
            assert p0_w == p_w
            assert p0_h == p_h
            textures_pre0_arrays = textures_pre0[3:]
            textures_pre_arrays = textures_pre[3:]
            triangles_pre1_arrays = [pyopencl.array.concatenate((x, y))
                              for x, y in zip(textures_pre0_arrays, textures_pre_arrays)]
            triangles_pre1 = [length, p0_w, p0_h] + triangles_pre1_arrays
        return self.render_triangles_preprocessed(
            size, view_dist, draw_dist, camera,
            triangles_pre1, textures_pre1,
            render_approach)
