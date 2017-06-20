# futracer

Race through breathtaking 3-D graphics with Futhark through OpenCL
(*not* OpenGL)!

Run `make` to build the library, and then run `./futcubes.py`,
`./futfly.py`, or `./futdoom.py` to run the example programs.  Use the
`--help` argument to see which settings exist.

There are two rendering approaches: `redomap` (the default) and
`scatter_bbox`.  Both are pretty slow.  

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

Use the arrow keys for now.  Use Page Up and Page Down to adjust the
view distance for rendering (fun!).
