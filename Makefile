.PHONY: all clean run

all: futracerlib.py

futracerlib.py: futracerlib.fut futracerlib/*.fut futracerlib/lib
	futhark pyopencl --library futracerlib.fut

futracerlib/lib: futracerlib/futhark.pkg
	cd futracerlib && futhark pkg sync

clean:
	rm -f futracerlib.py futracerlib.pyc futracer.pyc
	rm -rf __pycache__
