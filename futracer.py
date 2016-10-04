#!/usr/bin/env python

import sys
import argparse
import collections
import math
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
        
    def rotate_point(self, angles, origo, point):
        args = angles + origo + point
        return self.futhark.rotate_point_raw(*args)

    def loop(self):
        triangle = [(200.0, 100.0, 500.0),
                    (600.0, 100.0, 500.0),
                    (400.0, 500.0, 500.0)]

        t0 = [(200.0, 100.0, 100.0),
              (200.0, 300.0, 100.0),
              (400.0, 100.0, 100.0)]
        t1 = [(400.0, 100.0, 100.0),
              (400.0, 300.0, 100.0),
              (200.0, 300.0, 100.0)]
        origo = (300.0, 200.0, 200.0)
        s0 = [t0, t1]
        s1 = [[self.rotate_point((0.0, math.pi / 2, 0.0), origo, p) for p in t]
              for t in s0]
        cube = s0 + s1
        
        frame = numpy.empty(self.size, dtype=numpy.uint32)
        while True:
            fps = self.clock.get_fps()

            frame.fill(0)

            # origo = (400.0, 300.0, 500.0)
            # angles = (0.01, 0.005, 0.0025)
            # triangle = [self.rotate_point(angles, origo, point)
            #             for point in triangle]
            # t = list(itertools.chain(*triangle))

            cube = [[self.rotate_point((0.0, 0.01, 0.0), origo, p) for p in t]
                    for t in cube]

            p0s = [t[0] for t in cube]
            p1s = [t[1] for t in cube]
            p2s = [t[2] for t in cube]

            x0s = numpy.array([p[0] for p in p0s])
            y0s = numpy.array([p[1] for p in p0s])
            z0s = numpy.array([p[2] for p in p0s])

            x1s = numpy.array([p[0] for p in p1s])
            y1s = numpy.array([p[1] for p in p1s])
            z1s = numpy.array([p[2] for p in p1s])

            x2s = numpy.array([p[0] for p in p2s])
            y2s = numpy.array([p[1] for p in p2s])
            z2s = numpy.array([p[2] for p in p2s])
            
            frame = self.futhark.render_triangles_raw(
                frame, x0s, y0s, z0s, x1s, y1s, z1s, x2s, y2s, z2s).get()

            pygame.surfarray.blit_array(self.screen, frame)
            pygame.display.flip()

            # Check events.
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return 0

                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_q:
                        return 0

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
