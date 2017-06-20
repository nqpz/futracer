import collections

GameMapRaw = collections.namedtuple(
    'GameMapRaw',
    ['aliases', 'functions', 'cells'])

GameMapEvald = collections.namedtuple(
    'GameMapEvald',
    ['cells'])

Cell = collections.namedtuple(
    'Cell',
    ['floor', 'ceiling', 'height', 'walls'])

Walls = collections.namedtuple(
    'Walls',
    ['north', 'east', 'south', 'west'])


def load_map(path):
    with open(path) as f:
        d = f.read()
    d = d.strip()

    raw = parse_map(d)
    evald = eval_map(raw)
    return evald


def parse_map(s):
    definitions, textmap = s.split('\n\n\n')

    aliases = {}
    functions = {}

    lines = definitions.split('\n')
    lines.append('')
    lines = [line for line in lines
             if not line.strip().startswith('#')]

    def parse_values(name, indentation, i):
        values = {}

        while i < len(lines):
            line = lines[i]
            if len(line) - len(line.lstrip()) != indentation:
                return values, i
            name, value = line.split(':')
            name = name.strip()
            if value.startswith('@'):
                function_name = value[1:]
                call_values, i = parse_values(name, indentation + 1, i + 1)
                values[name] = ('call', function_name, call_values)
            else:
                values[name] = value
                i += 1

    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue

        name, value = line.split('=')
        value = value.strip()
        if value:
            aliases[name] = value
            i += 1
        else:
            letter = name[0]
            try:
                arg = name[1]
            except IndexError:
                arg = None
            values, i = parse_values(name, 1, i + 1)
            functions[letter] = (arg, values)

    cells = {}

    lines = textmap.strip().split('\n')
    for y in range(len(lines)):
        line = lines[y]
        for x in range(0, len(line), 2):
            val = line[x:x + 2]
            if val.strip():
                cells[(x // 2, y)] = val

    raw = GameMapRaw(aliases, functions, cells)
    return raw


def eval_map(raw):
    cells = {}
    for pos, value in raw.cells.items():
        cells[pos] = eval_cell(raw, pos, value)
    return GameMapEvald(cells)

def eval_cell(raw, pos, s):
    name = s[0]
    arg = s[1]

    param, values = raw.functions[name]
    if param == 'N':
        arg = int(arg)
    aliases = raw.aliases.copy()
    aliases[param] = arg
    values_new = {}
    for k, v in values.items():
        if isinstance(v, tuple):
            if v[0] == 'call':
                function_name = v[1]
                args = v[2]
                v_new = call_builtin(raw, aliases, pos, function_name, args)
        else:
            v_new = eval_value(aliases, v)
            values_new[k] = v_new
        values_new[k] = v_new
    cell = Cell(**values_new)
    return cell

def eval_value(aliases, v):
    try:
        v_new = aliases[v]
    except KeyError:
        v_new = v
    if isinstance(v_new, str) and v_new.startswith('HSV'):
        v_new = ('hsv', list(map(float, v_new.split()[1:])))
    return v_new

def call_builtin(raw, aliases, pos, name, args):
    builtins = {
        'standard_walls': builtin_standard_walls,
        'walls_with_door': builtin_walls_with_door
    }
    return builtins[name](raw, aliases, pos, args)

def builtin_standard_walls(raw, aliases, pos, kwargs):
    wall = eval_value(aliases, kwargs['wall'])
    number = eval_value(aliases, kwargs['number'])

    x, y = pos
    north = (x, y - 1)
    east = (x + 1, y)
    south = (x, y + 1)
    west = (x - 1, y)

    textures = []
    for i in range(number):
        textures.append((i, wall))

    walls = {
        'north': textures if north not in raw.cells.keys() else [],
        'east': textures if east not in raw.cells.keys() else [],
        'south': textures if south not in raw.cells.keys() else [],
        'west': textures if west not in raw.cells.keys() else []
    }
    walls = Walls(**walls)
    return walls

def builtin_walls_with_door(raw, aliases, pos, kwargs):
    door = eval_value(aliases, kwargs['door'])
    wall = eval_value(aliases, kwargs['wall'])
    number = eval_value(aliases, kwargs['number'])

    x, y = pos
    north = (x, y - 1)
    east = (x + 1, y)
    south = (x, y + 1)
    west = (x - 1, y)

    textures = [(0, door)]
    for i in range(1, number):
        textures.append((i, wall))

    walls = {
        'north': [],
        'east': [],
        'south': [],
        'west': []
    }

    assert sum(int(direc not in raw.cells.keys())
               for direc in (north, east, south, west)) == 1

    if north not in raw.cells.keys():
        walls['north'] = textures
    elif east not in raw.cells.keys():
        walls['east'] = textures
    elif south not in raw.cells.keys():
        walls['south'] = textures
    elif west not in raw.cells.keys():
        walls['west'] = textures

    walls = Walls(**walls)
    return walls
