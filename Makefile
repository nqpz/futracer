.PHONY: all clean

all: futracerlib.py

futracerlib.py: futracerlib.fut
	futhark-pyopencl --library futracerlib.fut

clean:
	rm -f futracerlib.py
