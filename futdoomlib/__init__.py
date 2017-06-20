import argparse

import futdoomlib.runner as runner

def main(racer_module, args):
    def size(s):
        return tuple(map(int, s.split('x')))

    arg_parser = argparse.ArgumentParser(description='DOOM.  Use the arrow keys to move around.  Interact with space.')
    arg_parser.add_argument('--scale-to', type=size, metavar='WIDTHxHEIGHT',
                            help='scale the frames to this size when showing them')
    args = arg_parser.parse_args(args)

    doom = runner.Doom(racer_module, args.scale_to)
    return doom.run()
