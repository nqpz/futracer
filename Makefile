.PHONY: all clean run

all: futracerlib.py

futracerlib.py: futracerlib.fut futracerlib/*.fut futracerlib/*/*.fut
	futhark-pyopencl --library futracerlib.fut

run: futracerlib.py
	./futracer.py

clean:
	rm -f futracerlib.py futracer.pyc
