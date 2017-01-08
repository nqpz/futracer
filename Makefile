.PHONY: all clean run

all: futracerlib.py 

futracerlib.py: futracerlib.fut futracerlib/*.fut futracerlib/*/*.fut
	futhark-pyopencl --library futracerlib.fut

clean:
	rm -f futracerlib.py

run: futracerlib.py
	./futracer.py
