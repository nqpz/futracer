import sys
import os.path
import time

import pygame

import futdoomlib.resources as resources
import futdoomlib.mapper as mapper

def square2d_to_triangles2d(square2d):
    left_upper, right_lower = square2d
    x_lu, y_lu = left_upper
    x_rl, y_rl = right_lower
    return [
        [(x_lu, y_lu), (x_lu, y_rl), (x_rl, y_lu)],
        [(x_rl, y_rl), (x_rl, y_lu), (x_lu, y_rl)]
    ]

class Doom:
    def __init__(self, racer_module, scale_to):
        self.racer_module = racer_module
        self.scale_to = scale_to
        self.size = (640, 360)
        self.view_dist = 400.0
        self.draw_dist = 2000.0

    def run(self):
        self.racer = self.racer_module.FutRacer()
        self.load_resources()
        self.setup_screen()
        self.loop()

    def load_resources(self):
        textures = {}
        textures_list = []
        for path, i in zip(resources.textures_paths,
                           range(len(resources.textures_paths))):
            texture = self.racer.load_double_texture(path)
            name = os.path.basename(path).rsplit('.', 1)[0]
            textures[name] = (i * 2, texture)
            textures_list.append(texture)
        self.textures = textures
        self.textures_pre = self.racer.preprocess_textures(textures_list)

        triangles_all_pre = {}
        textures_used_all = set()
        for path in resources.maps_paths:
            gamemap = mapper.load_map(path)
            triangles, textures_used = self.make_map_triangles(gamemap)
            name = os.path.basename(path).rsplit('.', 1)[0]
            triangles_all_pre[name] = self.racer.preprocess_triangles(triangles)
            textures_used_all.update(textures_used)
        self.triangles_pre = triangles_all_pre
        self.textures_used = textures_used_all
        # FIXME: Actually use textures_used to reduce space use.

        pygame.font.init()
        self.font = pygame.font.Font(None, 36)

    def make_map_triangles(self, gamemap):
        f = 200

        triangles_all = []
        textures_used = set()

        for pos, cell in gamemap.cells.items():
            xp, zp = pos

            # Floor and ceiling.
            square2d = [[xp - 0.5, zp - 0.5],
                        [xp + 0.5, zp + 0.5]]
            triangles2d = square2d_to_triangles2d(square2d)
            for y, texture_name in ((0, cell.floor), (cell.height, cell.ceiling)):
                i_base, _ = self.textures[texture_name]
                triangles = [[[x * f, (0 - y) * f, z * f]
                              for x, z in t] + [[2, [0, 0, 0], i]]
                             for t, i in zip(triangles2d, (i_base, i_base + 1))]
                triangles_all.extend(triangles)
                textures_used.add(texture_name)

            # Walls.
            direcs = [(cell.walls.north, [[xp - 0.5, -1], [xp + 0.5, 0]],
                       zp - 0.5, lambda p, n: [p[0], p[1], n]),
                      (cell.walls.east, [[zp - 0.5, -1], [zp + 0.5, 0]],
                       xp + 0.5, lambda p, n: [n, p[1], p[0]]),
                      (cell.walls.south, [[xp - 0.5, -1], [xp + 0.5, 0]],
                       zp + 0.5, lambda p, n: [p[0], p[1], n]),
                      (cell.walls.west,  [[zp - 0.5, -1], [zp + 0.5, 0]],
                       xp - 0.5, lambda p, n: [n, p[1], p[0]])]
            for textures, square2d, n, fun in direcs:
                triangles2d = square2d_to_triangles2d(square2d)
                for y_offset, texture_name in textures:
                    i_base, _ = self.textures[texture_name]
                    triangles = [[(lambda x, y, z:
                                   [x * f, (y - y_offset) * f, z * f])(*fun(p, n))
                                  for p in t] + [[2, [0, 0, 0], i]]
                                 for t, i in zip(triangles2d, (i_base, i_base + 1))]
                    triangles_all.extend(triangles)
                    textures_used.add(texture_name)

        return triangles_all, textures_used

    def setup_screen(self):
        # Check related input.
        if self.scale_to is not None:
            if not all(scaled % orig == 0
                       for scaled, orig
                       in zip(self.scale_to, self.size)):
                print('WARNING: Scale size is not a multiplicative of base size; expect blurriness.', file=sys.stderr)

        # Setup pygame.
        pygame.display.init()
        pygame.display.set_caption('futdoom')
        self.screen = pygame.display.set_mode(
            self.scale_to if self.scale_to else self.size)
        if self.scale_to:
            self.screen_base = pygame.Surface(self.size)
        self.clock = pygame.time.Clock()

    def message(self, what, where):
        text = self.font.render(what, 1, (0, 0, 255))
        self.screen.blit(text, where)

    def loop(self):
        camera = [[700.0, -180.0, 700.0], [0.0, 0.0, 0.0]]

        keys_holding = {}
        for x in [pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT,
                  pygame.K_PAGEUP, pygame.K_PAGEDOWN]:
            keys_holding[x] = False

        def inf_range():
            i = 0
            while True:
                yield i
                i += 1

        level = 'start'

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

            frame = self.racer.render_triangles_preprocessed(
                self.size, self.view_dist, self.draw_dist, camera,
                self.triangles_pre[level], self.textures_pre)
            time_end = time.time()
            frame = frame.get()
            futhark_dur_ms = (time_end - time_start) * 1000
            if not self.scale_to:
                pygame.surfarray.blit_array(self.screen, frame)
            else:
                pygame.surfarray.blit_array(self.screen_base, frame)
                pygame.transform.scale(self.screen_base, self.scale_to, self.screen)

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

            if keys_holding[pygame.K_PAGEUP]:
                self.view_dist += 10.0
            if keys_holding[pygame.K_PAGEDOWN]:
                self.view_dist -= 10.0
                if self.view_dist < 1.0:
                    self.view_dist = 1.0

            self.clock.tick()
