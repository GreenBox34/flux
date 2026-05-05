CC = as
GASFLAGS = -g --gdwarf-2
LDFLAGS = -nostdlib -e _start

flux: flux.o
	ld $(LDFLAGS) flux.o -o flux

flux.o: flux.s
	$(CC) $(GASFLAGS) -o flux.o flux.s

run: flux
	./flux

clean:
	-rm -f *.o flux
