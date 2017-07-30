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
    def __init__(self, racer_module, level_path, scale_to=None,
                 render_approach=None, auto_fps=False):
        self.racer_module = racer_module
        self.level_path = level_path
        self.scale_to = scale_to
        self.render_approach = render_approach
        if render_approach is None:
            render_approach = 'chunked'
        self.auto_fps = auto_fps
        self.size = (640, 360)
        self.view_dist = 400.0
        self.draw_dist = 2000.0
        self.n_draw_rects = [1, 1]

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

        if not self.level_path:
            self.level_path = os.path.join(resources.maps_dir, 'start.map')
        elif self.level_path == '-':
            self.level_path = 0

        gamemap = mapper.load_map(self.level_path)
        triangles, textures_used = self.make_map_triangles(gamemap)
        name = os.path.basename(path).rsplit('.', 1)[0]
        self.triangles_pre = self.racer.preprocess_triangles(triangles)
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
            square2d = [[xp * f - f // 2, zp * f - f // 2],
                        [xp * f + f // 2, zp * f + f // 2]]
            triangles2d = square2d_to_triangles2d(square2d)
            for y, texture in ((0, cell.floor), (cell.height, cell.ceiling)):
                if isinstance(texture, tuple):
                    assert texture[0] == 'hsv'
                    hsv = texture[1]
                    texfun = lambda _: [1, hsv, 0]
                    i_base = 0 # Doesn't matter.
                else:
                    i_base, _ = self.textures[texture]
                    textures_used.add(texture)
                    texfun = lambda i: [2, [0, 0, 0], i]
                triangles = [[[x, (0 - y) * f, z]
                              for x, z in t] + [texfun(i)]
                             for t, i in zip(triangles2d, (i_base, i_base + 1))]
                triangles_all.extend(triangles)

            # Walls.
            direcs = [(cell.walls.north, [[xp * f - f // 2, -1], [xp * f + f // 2, 0]],
                       zp * f - f // 2, lambda p, n: [p[0], p[1], n]),
                      (cell.walls.east, [[zp * f - f // 2, -1], [zp * f + f // 2, 0]],
                       xp * f + f // 2, lambda p, n: [n, p[1], p[0]]),
                      (cell.walls.south, [[xp * f - f // 2, -1], [xp * f + f // 2, 0]],
                       zp * f + f // 2, lambda p, n: [p[0], p[1], n]),
                      (cell.walls.west,  [[zp * f - f // 2, -1], [zp * f + f // 2, 0]],
                       xp * f - f // 2, lambda p, n: [n, p[1], p[0]])]
            for textures, square2d, n, fun in direcs:
                triangles2d = square2d_to_triangles2d(square2d)
                for y_offset, texture in textures:
                    if isinstance(texture, tuple):
                        assert texture[0] == 'hsv'
                        hsv = texture[1]
                        texfun = lambda _: [1, hsv, 0]
                        i_base = 0 # Doesn't matter.
                    else:
                        i_base, _ = self.textures[texture]
                        textures_used.add(texture)
                        texfun = lambda i: [2, [0, 0, 0], i]
                    triangles = [[(lambda x, y, z:
                                   [x, (y - y_offset) * f, z])(*fun(p, n))
                                  for p in t] + [texfun(i)]
                                 for t, i in zip(triangles2d, (i_base, i_base + 1))]
                    triangles_all.extend(triangles)

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
                  pygame.K_PAGEUP, pygame.K_PAGEDOWN, pygame.K_1, pygame.K_2]:
            keys_holding[x] = False

        def inf_range():
            i = 0
            while True:
                yield i
                i += 1

        for i in inf_range():
            fps = self.clock.get_fps()
            time_start = time.time()

            frame = self.racer.render_triangles_preprocessed(
                self.size, self.view_dist, self.draw_dist, camera,
                self.triangles_pre, self.textures_pre, self.render_approach)
            time_end = time.time()
            frame = frame.get()
            futhark_dur_ms = (time_end - time_start) * 1000
            if not self.scale_to:
                pygame.surfarray.blit_array(self.screen, frame)
            else:
                pygame.surfarray.blit_array(self.screen_base, frame)
                pygame.transform.scale(self.screen_base, self.scale_to, self.screen)

            if self.auto_fps:
                if futhark_dur_ms > 20:
                    self.draw_dist /= 1.1
                else:
                    self.draw_dist += 10.0

            self.message('FPS: {:.02f}'.format(fps), (10, 10))
            self.message('Futhark: {:.02f} ms'.format(futhark_dur_ms), (10, 40))
            self.message('Draw distance: {:.02f}{}'.format(
                self.draw_dist, ' (auto)' if self.auto_fps else ''), (10, 70))
            self.message('Rendering approach: {}'.format(self.render_approach), (10, 100))
            if self.render_approach == 'chunked':
                self.message('# draw rects: x: {}, y: {}'.format(
                    *self.n_draw_rects), (10, 130))

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
                        self.render_approach = self.racer_module.next_elem(
                            self.racer_module.render_approaches,
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

            if keys_holding[pygame.K_1]:
                self.draw_dist -= 10.0
            if keys_holding[pygame.K_2]:
                self.draw_dist += 10.0

            self.clock.tick()
