#!/usr/bin/env python

import sys
import argparse
import collections
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

    def loop(self):
        # t = [-40.0, 40.0, 0.0,
        #      300.0, 40.0, 0.6,
        #      400.0, 500.0, 0.9]
        t = [-40.0, 40.0, 0.0,
             300.0, 40.0, 0.6,
             400.0, 500.0, 0.9]

        frame = numpy.empty(self.size, dtype=numpy.uint32)
        while True:
            fps = self.clock.get_fps()

            frame.fill(0)
            t[0] += 1.2
            frame = self.futhark.test(frame, *t).get()
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
