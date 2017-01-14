#!/usr/bin/env python3

import sys
import os.path
import math
import random
import argparse
import time

import pygame

import futracer


class FutCubes:
    def __init__(self, size=None, n_cubes=None, just_colors=False):
        if size is None:
            size = (800, 600)
        self.size = size
        if n_cubes is None:
            n_cubes = 2000
        self.n_cubes = n_cubes
        self.just_colors = just_colors
        self.draw_dist = 800.0

    def run(self):
        # Setup pygame.
        pygame.init()
        pygame.display.set_caption('futcubes')
        self.screen = pygame.display.set_mode(self.size)
        self.font = pygame.font.Font(None, 36)
        self.clock = pygame.time.Clock()

        # Load the library.
        self.racer = futracer.FutRacer()

        # Actually run!
        return self.loop()

    def message(self, what, where):
        text = self.font.render(what, 1, (255, 255, 255))
        self.screen.blit(text, where)

    def random_cubes(self, square_texture=None):
        t0 = [(200.0, 100.0, 200.0),
              (200.0, 300.0, 200.0),
              (400.0, 100.0, 200.0)]
        t1 = [(400.0, 300.0, 200.0),
              (400.0, 100.0, 200.0),
              (200.0, 300.0, 200.0)]
        origo = (300.0, 200.0, 300.0)
        s0 = [t0, t1]
        s1 = [[self.racer.rotate_point((0.0, math.pi / 2, 0.0), origo, p) for p in t]
              for t in s0]
        s2 = [[self.racer.rotate_point((0.0, -math.pi / 2, 0.0), origo, p) for p in t]
              for t in s0]
        s3 = [[self.racer.rotate_point((0.0, math.pi, 0.0), origo, p) for p in t]
              for t in s0]
        s4 = [[self.racer.rotate_point((math.pi / 2, 0.0, 0.0), origo, p) for p in t]
              for t in s0]
        s5 = [[self.racer.rotate_point((-math.pi / 2, 0.0, 0.0), origo, p) for p in t]
              for t in s0]
        half_cube_0 = s0 + s1 + s2 + s3 + s4 + s5

        if square_texture is not None:
            textures = [square_texture]
        else:
            textures = []

        half_cubes = []
        xr = 30000.0
        yr = 1000.0
        zr = 30000.0
        for i in range(self.n_cubes):
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
                return self.racer.rotate_point(
                    (ax, ay, az),
                    self.racer.translate_point((xm, ym, zm), origo),
                    self.racer.translate_point((xm, ym, zm), p))
            half_cube = [[move_point(p) for p in t] + [make_surf(i)]
                         for t, i in
                         zip(half_cube_0, range(len(half_cube_0)))]
            half_cubes.extend(half_cube)

        return half_cubes, textures

    def loop(self):
        if self.just_colors:
            triangles, textures = self.random_cubes()
        else:
            base_dir = os.path.dirname(__file__)
            sonic_texture = self.racer.load_double_texture(
                os.path.join(base_dir, 'data/sonic-texture.png'))
            textures_size = (100, 100)
            assert (textures_size[0], textures_size[1], 3) == sonic_texture.shape
            triangles, textures = self.random_cubes(sonic_texture)

        # The objects will not change (only the camera changes), so we
        # preprocess them to save important loop time.
        triangles_pre = self.racer.preprocess_triangles(triangles)
        textures_pre = self.racer.preprocess_textures(textures)

        camera = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]

        keys_holding = {}
        for x in [pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT]:
            keys_holding[x] = False

        def inf_range():
            i = 0
            while True:
                yield i
                i += 1

        for i in inf_range():
            fps = self.clock.get_fps()
            time_start = time.time()

            dynamic_triangle = [[-300, -300, 500],
                                [300, -300, 500],
                                [0, 300, 400],
                                [1, [240, 1, 1], 0]]
            dynamic_origo = [0, 0, 450]
            dynamic_angles = [i / 60.0, i / 80.0, i / 100.0]
            dynamic_triangle = self.racer.rotate_triangle(
                dynamic_angles, dynamic_origo, dynamic_triangle)

            frame = self.racer.render_triangles(
                self.size, self.draw_dist, camera,
                [dynamic_triangle], triangles_pre,
                None, textures_pre)
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
                p2 = self.racer.rotate_point(camera[1], camera[0], p1)
                camera[0] = list(p2)
            if keys_holding[pygame.K_DOWN]:
                p1 = camera[0][:]
                p1[2] -= 15
                p2 = self.racer.rotate_point(camera[1], camera[0], p1)
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
    arg_parser.add_argument('--cubes', type=int, metavar='N',
                            help='set the number of cubes in the world (defaults to 2000)')
    arg_parser.add_argument('--just-colors', action='store_true',
                            help='use random colors instead of the pretty texture')

    args = arg_parser.parse_args(args)

    cubes = FutCubes(size=args.size, n_cubes=args.cubes,
                     just_colors=args.just_colors)
    return cubes.run()

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
