#!/usr/bin/env python3

import sys

import futracer
import futdoomlib

def main(args):
    return futdoomlib.main(futracer, args)

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
