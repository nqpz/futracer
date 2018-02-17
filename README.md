# futracer

Race through breathtaking 3-D graphics with Futhark through OpenCL
(*not* OpenGL)!

Run `make` to build the library, and then run `./futcubes.py`,
`./futfly.py`, or `./futdoom.py` to run the example programs.  Use the
`--help` argument to see which settings exist.

There are two rendering approaches: `chunked` (the default) and
`scatter_bbox`.  Both are pretty slow, but `chunked` is faster.

*Click on the image to see a 1-minute video of `futcubes.py` in action.*
[![Video of futcubes](https://hongabar.org/~niels/futracer/futracer-textured-image.jpg)](https://hongabar.org/~niels/futracer/futracer-textured.webm)

*Click on the image to see a 1-minute video of `futfly.py` in action.*
[![Video of futfly](https://hongabar.org/~niels/futracer/futracer-futfly-image.jpg)](https://hongabar.org/~niels/futracer/futracer-futfly.webm)

*Click on the image to see a 30-second video of `futdoom.py` in action.*
[![Video of futdoom](https://hongabar.org/~niels/futracer/futracer-futdoom-image.jpg)](https://hongabar.org/~niels/futracer/futracer-futdoom.webm)


## Dependencies

futracer depends on the programming language Futhark;
see [http://futhark-lang.org/](http://futhark-lang.org/)
and
[https://github.com/HIPERFIT/futhark](https://github.com/HIPERFIT/futhark).

futracer also depends on PyGame, PyPNG (only `futcubes.py` and
`futdoom.py`), and NumPy.


## Keyboard controls

Use the arrow keys for now.  Use Page Down and Page Up to decrease and
increase the view distance for rendering (fun!).  Use 1 and 2 to
decrease and increase the draw distance.

Use R to switch rendering approaches.

For the `chunked` rendering approach, use A and D to decrease and
increase the number of draw rectangles on the X axis, and W and S on the
Y axis.  Sometime in the future this should be chosen automatically.
Warning: This might slow down the program to a crawl for some reason.


## Scripts

`futdoom.py` supports custom maps.  For an example of a (poorly)
randomly generated map, run:

```
./futdoomlib/scripts/generate_random_map.py | ./futdoom.py --auto-fps --level -
```
