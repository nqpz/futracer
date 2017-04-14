.PHONY: all clean run

all: futracerlib.py

futracerlib.py: futracerlib.fut futracerlib/*.fut
	futhark-pyopencl --library futracerlib.fut

clean:
	rm -f futracerlib.py futracerlib.pyc futracer.pyc
	rm -rf __pycache__
