jack_ripper:
	odin build . -out:jack_ripper

gpu:
	nvcc -arch=sm_87 -c add.cu -o add.o
	ar crv add.a add.o

clean:
	rm *.o *.a jack_ripper