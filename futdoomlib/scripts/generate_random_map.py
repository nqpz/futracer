#!/usr/bin/env python3

import sys
import random

try:
    size = int(sys.argv[1])
except Exception:
    size = 50

colors_only = sys.argv[2]

if colors_only:
    tiling_textures = ['HSV {} {} {}'.format(random.random() * 360.0,
                                             random.random() / 2.0 + 0.5,
                                             random.random() / 2.0 + 0.5)
                       for i in range(10)]
else:
    tiling_textures = ['stones', 'flowers', 'bricks', 'lines', 'squares0', 'squares1']

def t():
    return random.choice(tiling_textures)

letters = 'abcdefghij'

for letter in letters:
    print('''
{}N=
 floor:{}
 ceiling:{}
 height:N
 walls:@standard_walls
  wall:{}
  number:N\
'''.format(letter, t(), t(), t()))


m = [['  ' for _ in range(size)]
     for _ in range(size)]


ns = {}

p = (random.randrange(size), random.randrange(size))
for i in range(size * size // 3):
    x, y = p
    if x >= size:
        x = size - 1
    if x < 0:
        x = 0
    if y >= size:
        y = size - 1
    if y < 0:
        y = 0
    neighbors = [(x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y)]
    n_choices = list(filter(bool, (ns.get(p) for p in neighbors)))
    if not n_choices:
        n = random.randint(2, 6)
    else:
        n = random.choice(n_choices) + random.choice([-1, 0, +1])
        if n > 9:
            n = 0
        if n < 2:
            n = 2
    ns[p] = n
    letter = random.choice(letters)
    m[y][x] = '{}{}'.format(letter, n)
    neighbors_not_visited = list(filter(lambda p: p not in ns, neighbors))
    if neighbors_not_visited:
        p = random.choice(neighbors_not_visited)
    else:
        p = (random.randrange(size), random.randrange(size))

print('\n')
for y in range(size):
    for x in range(size):
        print(m[y][x], end='')
    print('')
