import argparse

import futdoomlib.runner as runner

def main(futracer, args):
    def size(s):
        return tuple(map(int, s.split('x')))

    arg_parser = argparse.ArgumentParser(description='DOOM.  Use the arrow keys to move around.  Interact with space.')
    arg_parser.add_argument('--level-path',
                            help='play this level from (defaults to "data/futdoom/maps/start.map")')
    arg_parser.add_argument('--scale-to', type=size, metavar='WIDTHxHEIGHT',
                            help='scale the frames to this size when showing them')
    arg_parser.add_argument('--render-approach',
                            choices=futracer.render_approaches,
                            default='chunked',
                            help='choose how to render a frame')
    arg_parser.add_argument('--auto-fps',
                            action='store_true',
                            help='automatically keep the FPS high by dynamically lowering the draw distance (experimental)')
    args = arg_parser.parse_args(args)

    doom = runner.Doom(futracer, level_path=args.level_path,
                       scale_to=args.scale_to,
                       render_approach=args.render_approach,
                       auto_fps=args.auto_fps)
    return doom.run()
