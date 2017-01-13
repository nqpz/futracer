#!/usr/bin/env python3

import sys
import os.path
import math
import random
import argparse
import itertools
import time
import colorsys

import pygame
import numpy
import png
import pyopencl as cl
import ctypes as ct

import futracerlib


def rgb8_to_hsv(rgb8):
    r8, g8, b8 = rgb8
    f = 255.0
    r, g, b = r8 / f, g8 / f, b8 / f
    h1, s1, v1 = colorsys.rgb_to_hsv(r, g, b)
    h360 = h1 * 360.0
    return (h360, s1, v1)

class FutRacer:
    def __init__(self, size=None):
        self.size = size
        if self.size is None:
            self.size = (800, 600)
        self.draw_dist = 800.0

    def race(self):
        # Setup pygame.
        pygame.init()
        pygame.display.set_caption('futracer')
        self.screen = pygame.display.set_mode(self.size)
        self.font = pygame.font.Font(None, 36)
        self.clock = pygame.time.Clock()

        # Load the library.
        self.futhark = futracerlib.futracerlib()

        return self.loop()

    def message(self, what, where):
        text = self.font.render(what, 1, (255, 255, 255))
        self.screen.blit(text, where)

    def translate_point(self, move, point):
        args = move + point
        return self.futhark.translate_point_raw(*args)

    def rotate_point(self, angles, origo, point):
        args = angles + origo + point
        return self.futhark.rotate_point_raw(*args)

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

        return (p0s, p1s, p2s, ss, x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
                s_types, s_hsv_vs, s_hsv_ss, s_hsv_vs, s_indices)

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

        return (len(textures), texture_w, texture_h,
                s_textures_hs_flat, s_textures_ss_flat, s_textures_vs_flat)

    def render_triangles_preprocessed(self, size, draw_dist, camera,
                                      triangles_pre, textures_pre):
        w, h = size

        ((c_x, c_y, c_z), (c_ax, c_ay, c_az)) = camera

        (p0s, p1s, p2s, ss, x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
         s_types, s_hsv_hs, s_hsv_ss, s_hsv_vs, s_indices) = triangles_pre

        (textures_len, texture_w, texture_h,
         s_textures_hs_flat, s_textures_ss_flat, s_textures_vs_flat) = textures_pre

        return self.futhark.render_triangles_raw(
            w, h, self.draw_dist,
            x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
            s_types, s_hsv_hs, s_hsv_ss, s_hsv_vs, s_indices,
            textures_len, texture_w, texture_h,
            s_textures_hs_flat, s_textures_ss_flat, s_textures_vs_flat,
            c_x, c_y, c_z, c_ax, c_ay, c_az)

    def render_triangles(self, size, draw_dist, camera, triangles, textures):
        triangles_pre = self.preprocess_triangles(triangles)
        textures_pre = self.preprocess_triangles(textures)
        return self.render_triangles_preprocessed(
            size, draw_dist, camera,
            triangles_pre, textures_pre)

    def random_cubes(self, square_texture=None):
        t0 = [(200.0, 100.0, 200.0),
              (200.0, 300.0, 200.0),
              (400.0, 100.0, 200.0)]
        t1 = [(400.0, 300.0, 200.0),
              (400.0, 100.0, 200.0),
              (200.0, 300.0, 200.0)]
        origo = (300.0, 200.0, 300.0)
        s0 = [t0, t1]
        s1 = [[self.rotate_point((0.0, math.pi / 2, 0.0), origo, p) for p in t]
              for t in s0]
        s2 = [[self.rotate_point((0.0, -math.pi / 2, 0.0), origo, p) for p in t]
              for t in s0]
        s3 = [[self.rotate_point((0.0, math.pi, 0.0), origo, p) for p in t]
              for t in s0]
        s4 = [[self.rotate_point((math.pi / 2, 0.0, 0.0), origo, p) for p in t]
              for t in s0]
        s5 = [[self.rotate_point((-math.pi / 2, 0.0, 0.0), origo, p) for p in t]
              for t in s0]
        half_cube_0 = s0 + s1 + s2 + s3 + s4 + s5

        half_cube_0 = [[tuple(numpy.float32(x) for x in p) for p in t]
                       for t in half_cube_0]

        if square_texture is not None:
            textures = [square_texture]
        else:
            textures = []

        n = 2000
        half_cubes = []
        xr = 30000.0
        yr = 1000.0
        zr = 30000.0
        for i in range(n):
            xm = random.random() * xr - xr / 2
            ym = random.random() * yr - yr / 2
            zm = random.random() * zr - zr / 2
            ax = random.random() * math.pi
            ay = random.random() * math.pi
            az = random.random() * math.pi
            if square_texture is not None:
                def make_surf(i):
                    surf = (2, (0.0, 0.0, 0.0), i % 2)
                    return surf
            else:
                # Use a random color.
                hsv = (random.random() * 360.0,
                       random.random(),
                       random.random())
                surf = (1, hsv, -1)
                make_surf = lambda i: surf
            def move_point(p):
                return self.rotate_point(
                    (ax, ay, az),
                    self.translate_point((xm, ym, zm), origo),
                    self.translate_point((xm, ym, zm), p))
            half_cube = [[move_point(p) for p in t] + [make_surf(i)]
                         for t, i in
                         zip(half_cube_0, range(len(half_cube_0)))]
            half_cubes.extend(half_cube)

        return half_cubes, textures

    def race_track(self):
        def straight(start, width, length, turn=None):
            sx, sy, sz = start
            t0 = ((sx - width / 2, sy, sz),
                  (sx + width / 2, sy, sz),
                  (sx + width / 2, sy, sz + length))
            t1 = ((sx + width / 2, sy, sz + length),
                  (sx - width / 2, sy, sz + length),
                  (sx - width / 2, sy, sz))
            plane = [t0, t1]
            end = (sx, sy, sz + length)
            if turn is not None:
                angles = (0.0, turn, 0.0)
                green = (1, (120.0, 1.0, 1.0), -1)
                plane = [[self.rotate_point(angles, start, p)
                          for p in t] + [green]
                         for t in plane]
                end = self.rotate_point(angles, start, end)
            return end, plane

        class N:
            pass
        glob = N()
        glob.cur = (0.0, 300.0, 0.0)
        glob.turn = 0.0
        triangles = []
        def magic(width, length, lturn=None):
            if lturn is not None:
                glob.turn += lturn
            glob.cur, plane = straight(glob.cur, width, length, glob.turn)
            triangles.extend(plane)

        for i in range(100):
            magic(600.0, 800.0, 0.05)

        self.draw_dist = 2000.0
        textures = []
        return triangles, textures

    def loop(self):
        camera = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]

        keys_holding = {}
        for x in [pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT]:
            keys_holding[x] = False

        # triangles, textures = self.race_track()
        # triangles, textures = self.random_cubes()

        n_channels = 3
        texture_w = 100
        texture_h = 100
        base_dir = os.path.dirname(__file__)
        sonic_texture_raw = png.Reader(filename=os.path.join(
            base_dir, 'data/sonic-texture.png'))
        s_w, s_h, s_pixels, s_meta = sonic_texture_raw.asRGB8()
        assert s_w == texture_w
        assert s_h == texture_h
        assert s_meta['planes'] == n_channels
        rgbs_1d = numpy.fromiter(itertools.chain(*s_pixels), dtype='uint8')
        rgbs_2d = numpy.reshape(rgbs_1d, (s_h * s_w, n_channels))
        hsvs_2d = numpy.fromiter(itertools.chain(*map(rgb8_to_hsv, rgbs_2d)), dtype='float32')
        hsvs_3d = numpy.reshape(hsvs_2d, (s_h, s_w, n_channels))
        sonic_texture = hsvs_3d
        triangles, textures = self.random_cubes(sonic_texture)

        # The objects will not change (only the camera changes), so we
        # preprocess them to save important loop time.
        triangles_pre = self.preprocess_triangles(triangles)
        textures_pre = self.preprocess_textures(textures)

        while True:
            fps = self.clock.get_fps()
            time_start = time.time()
            frame = self.render_triangles_preprocessed(
                self.size, self.draw_dist, camera,
                triangles_pre, textures_pre)
            time_end = time.time()
            frame = frame.get()
            futhark_dur_ms = (time_end - time_start) * 1000
            pygame.surfarray.blit_array(self.screen, frame)

            self.message('FPS: {:.02f}'.format(fps), (10, 10))
            self.message('Futhark: {:.02f} ms'.format(futhark_dur_ms), (10, 40))

            pygame.display.flip()

            # Check events.
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return 0

                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_q:
                        return 0
                    if event.key in keys_holding.keys():
                        keys_holding[event.key] = True

                elif event.type == pygame.KEYUP:
                    if event.key in keys_holding.keys():
                        keys_holding[event.key] = False

            if keys_holding[pygame.K_UP]:
                p1 = camera[0][:]
                p1[2] += 15
                p2 = self.rotate_point(camera[1], camera[0], p1)
                camera[0] = list(p2)
            if keys_holding[pygame.K_DOWN]:
                p1 = camera[0][:]
                p1[2] -= 15
                p2 = self.rotate_point(camera[1], camera[0], p1)
                camera[0] = list(p2)
            if keys_holding[pygame.K_LEFT]:
                camera[1][1] -= 0.04
            if keys_holding[pygame.K_RIGHT]:
                camera[1][1] += 0.04

            self.clock.tick()

def main(args):
    def size(s):
        return tuple(map(int, s.split('x')))

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('--size', type=size, metavar='WIDTHxHEIGHT',
                            help='set the size of the racing game window')

    args = arg_parser.parse_args(args)

    racer = FutRacer(size=args.size)
    return racer.race()

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
