#!/usr/bin/env python3

import sys
import os.path
import math
import random
import argparse
import time
import itertools
import functools

import pygame

import futracer


class FutFly:
    def __init__(self, size=None, render_approach=None):
        if size is None:
            size = (800, 600)
        self.size = size
        if render_approach is None:
            render_approach = 'chunked'
        self.render_approach = render_approach
        self.view_dist = 600.0
        self.draw_dist = 2000.0
        self.n_draw_rects = [1, 1]

    def fly(self):
        # Setup pygame.
        pygame.init()
        pygame.display.set_caption('futfly')
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

    def terrain(self):
        depth = 100
        width = 100
        size = 300
        size_vert = size / 2**0.5
        point_rows = []

        # Make points.
        for i in range(depth):
            row = []
            indent = (i % 2) * (size / 2)
            for j in range(width):
                y = 0
                x = j * size + indent
                z = i * size_vert
                row.append([x, y, z])
            point_rows.append(row)

        # Make spikes.
        for c in range(int(depth * width)):
            i = random.randrange(1, depth - 1)
            j = random.randrange(1, width - 1)
            fluct = 1000.0
            point_rows[j][i][1] = random.random() * fluct - fluct / 2.0

        # Smooth areas.
        for c in range(int(depth * width)):
            i = random.randrange(1, depth - 1)
            j = random.randrange(1, width - 1)

            avg = sum(point_rows[i + io][j + jo][1] for jo, io in
                      ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1))) / 8.0
            point_rows[i][j][1] = avg

        # Make triangles.
        triangle_rows = []
        for row0, row1, i in zip(point_rows, point_rows[1:], range(depth)):
            if i % 2 == 1:
                row0, row1 = row1, row0
            triangle_row = []
            for i in range(0, width - 1):
                for p0, p1, p2 in [(row0[i], row0[i + 1], row1[i]),
                                   (row1[i], row1[i + 1], row0[i + 1])]:
                    hsv = [random.random() * 360.0,
                           random.random() * 0.5 + 0.5,
                           random.random() * 0.5 + 0.5]
                    surface = [1, hsv, -1]
                    triangle = [p0, p1, p2, surface]
                    triangle_row.append(triangle)
            triangle_rows.append(triangle_row)

        def h_avg(h0, h1):
            h0, h1 = (h0, h1) if h0 < h1 else (h1, h0)
            diff_a = h1 - h0
            diff_b = h0 + 360.0 - h1
            h =  h0 + diff_a / 2.0 if diff_a < diff_b else (h1 + diff_b / 2.0) % 360.0
            return h

        def hsv_avg(xs):
            h = functools.reduce(h_avg, (x[0] for x in xs))
            s = sum(x[1] for x in xs) / len(xs)
            v = sum(x[2] for x in xs) / len(xs)
            return (h, s, v)

        # Smooth color transitions.
        for c in range(int(depth * width * 20)):
            i = random.randrange(1, depth - 2)
            j = random.randrange(1, width * 2 - 3)

            neigs = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
            avg = hsv_avg([triangle_rows[i + io][j + jo][3][1]
                           for io, jo in neigs])
            triangle_rows[i][j][3][1] = avg

        triangles = list(itertools.chain(*triangle_rows))
        return triangles, []

    def loop(self):
        triangles, textures = self.terrain()

        # The objects will not change (only the camera changes), so we
        # preprocess them to save important loop time.
        triangles_pre = self.racer.preprocess_triangles(triangles)
        textures_pre = self.racer.preprocess_textures(textures)

        camera = [[15000.0, -500.0, 0.0], [0.0, 0.0, 0.0]]

        keys_holding = {}
        for x in [pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT,
                  pygame.K_PAGEUP, pygame.K_PAGEDOWN]:
            keys_holding[x] = False

        def inf_range():
            i = 0
            while True:
                yield i
                i += 1

        for i in inf_range():
            fps = self.clock.get_fps()
            time_start = time.time()

            frame = self.racer.render_triangles(
                self.size, self.view_dist, self.draw_dist, camera,
                None, triangles_pre,
                None, textures_pre, self.render_approach, self.n_draw_rects)
            time_end = time.time()
            frame = frame.get()
            futhark_dur_ms = (time_end - time_start) * 1000
            pygame.surfarray.blit_array(self.screen, frame)

            self.message('FPS: {:.02f}'.format(fps), (10, 10))
            self.message('Futhark: {:.02f} ms'.format(futhark_dur_ms), (10, 40))
            self.message('Rendering approach: {}'.format(self.render_approach), (10, 70))
            if self.render_approach == 'chunked':
                self.message('# draw rects: x: {}, y: {}'.format(
                    *self.n_draw_rects), (10, 100))

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

                    if event.key == pygame.K_r:
                        self.render_approach = futracer.next_elem(futracer.render_approaches,
                                                                  self.render_approach)
                    if event.key == pygame.K_a:
                        self.n_draw_rects[0] = max(1, self.n_draw_rects[0] - 1)
                    if event.key == pygame.K_d:
                        self.n_draw_rects[0] = self.n_draw_rects[0] + 1
                    if event.key == pygame.K_w:
                        self.n_draw_rects[1] = max(1, self.n_draw_rects[1] - 1)
                    if event.key == pygame.K_s:
                        self.n_draw_rects[1] = self.n_draw_rects[1] + 1

                elif event.type == pygame.KEYUP:
                    if event.key in keys_holding.keys():
                        keys_holding[event.key] = False

            if keys_holding[pygame.K_UP]:
                camera[1][0] -= 0.02
            if keys_holding[pygame.K_DOWN]:
                camera[1][0] += 0.02

            # The turning code below will not work without some axis-changing
            # math, so I'll just let it stay until someone figures that out.

            # if keys_holding[pygame.K_LEFT]:
            #     camera[1][1] -= 0.02
            # if keys_holding[pygame.K_RIGHT]:
            #     camera[1][1] += 0.02

            if keys_holding[pygame.K_PAGEUP]:
                self.view_dist += 10.0
            if keys_holding[pygame.K_PAGEDOWN]:
                self.view_dist -= 10.0
                if self.view_dist < 1.0:
                    self.view_dist = 1.0

            # Always fly forwards.
            p1 = camera[0][:]
            p1[2] += 10
            p2 = self.racer.rotate_point(camera[1], camera[0], p1)
            camera[0] = list(p2)

            self.clock.tick()

def main(args):
    def size(s):
        return tuple(map(int, s.split('x')))

    arg_parser = argparse.ArgumentParser(description='Use the up and down arrow keys to fly.  Use Page Up and Page Down to adjust the view distance.')
    arg_parser.add_argument('--size', type=size, metavar='WIDTHxHEIGHT',
                            help='set the size of the racing game window')
    arg_parser.add_argument('--render-approach',
                            choices=futracer.render_approaches,
                            default='chunked',
                            help='choose how to render a frame')

    args = arg_parser.parse_args(args)

    fly = FutFly(size=args.size, render_approach=args.render_approach)
    return fly.fly()

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
