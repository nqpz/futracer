#!/usr/bin/env python3

import sys
import math
import random
import argparse
import itertools
import time

import pygame
import numpy

import futracerlib


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

    def random_cubes(self):
        t0 = [(200.0, 100.0, 200.0),
              (200.0, 300.0, 200.0),
              (400.0, 100.0, 200.0)]
        t1 = [(400.0, 100.0, 200.0),
              (400.0, 300.0, 200.0),
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

        n = 2000
        xms = []
        yms = []
        zms = []
        axs = []
        ays = []
        azs = []

        for i in range(n):
            xms.append(random.random() * 20000.0 - 10000.0)
            yms.append(random.random() * 1000.0 - 500.0)
            zms.append(random.random() * 20000.0 - 10000.0)
            axs.append(random.random() * math.pi)
            ays.append(random.random() * math.pi)
            azs.append(random.random() * math.pi)

        half_cubes = []
        for i in range(n):
            xm = xms[i]
            ym = yms[i]
            zm = zms[i]
            ax = axs[i]
            ay = ays[i]
            az = azs[i]
            half_cube = [[self.rotate_point((ax, ay, az),
                                            self.translate_point((xm, ym, zm), origo),
                                            self.translate_point((xm, ym, zm), p)) for p in t]
                         for t in half_cube_0]
            half_cubes.extend(half_cube)

        return half_cubes

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
                plane = [[self.rotate_point(angles, start, p)
                          for p in t] for t in plane]
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
        return triangles

    def loop(self):
        camera = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]

        keys_holding = {}
        for x in [pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT]:
            keys_holding[x] = False

        # ps = self.random_cubes()
        ps = self.race_track()

        p0s = [t[0] for t in ps]
        p1s = [t[1] for t in ps]
        p2s = [t[2] for t in ps]

        x0s = numpy.array([p[0] for p in p0s]).astype('float32')
        y0s = numpy.array([p[1] for p in p0s]).astype('float32')
        z0s = numpy.array([p[2] for p in p0s]).astype('float32')

        x1s = numpy.array([p[0] for p in p1s]).astype('float32')
        y1s = numpy.array([p[1] for p in p1s]).astype('float32')
        z1s = numpy.array([p[2] for p in p1s]).astype('float32')

        x2s = numpy.array([p[0] for p in p2s]).astype('float32')
        y2s = numpy.array([p[1] for p in p2s]).astype('float32')
        z2s = numpy.array([p[2] for p in p2s]).astype('float32')

        while True:
            fps = self.clock.get_fps()
            ((c_x, c_y, c_z), (c_ax, c_ay, c_az)) = camera
            time_start = time.time()
            frame = self.futhark.render_triangles_raw(
                self.size[0], self.size[1], self.draw_dist,
                x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s,
                c_x, c_y, c_z, c_ax, c_ay, c_az)
            time_end = time.time()
            frame = frame.get()
            futhark_dur_ms = (time_end - time_start) * 1000
            pygame.surfarray.blit_array(self.screen, frame)

            self.message('FPS: {:.02f}'.format(fps), (10, 10))
            self.message('Futhark only: {:.02f} ms'.format(futhark_dur_ms), (10, 40))

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
