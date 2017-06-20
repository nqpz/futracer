import os
import os.path

def file_paths(path):
    return [os.path.join(path, filename)
            for filename in os.listdir(path)]

data_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'data', 'futdoom'))
textures_dir = os.path.join(data_dir, 'textures')
maps_dir = os.path.join(data_dir, 'maps')
misc_dir = os.path.join(data_dir, 'misc')

textures_paths = file_paths(textures_dir)
maps_paths = file_paths(maps_dir)
misc_paths = file_paths(misc_dir)
