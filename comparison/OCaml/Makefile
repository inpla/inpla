CC      = ocamlopt
CFLAGS  = 
BENCHMARK  = bash ../tools/sptest_commands.sh
TARGET  = nqueen12 ack3_11 fib38 bsort20000 isort20000 qsort260000 msort260000
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(TARGET)

nqueen12: nqueen12.ml
	$(CC) $(CFLAGS) $< -o $@

ack3_11: ack3_11.ml
	$(CC) $(CFLAGS) $< -o $@

fib38: fib38.ml
	$(CC) $(CFLAGS) $< -o $@

bsort20000: bsort20000.ml
	$(CC) $(CFLAGS) $< -o $@

isort20000: isort20000.ml
	$(CC) $(CFLAGS) $< -o $@

qsort260000: qsort260000.ml
	$(CC) $(CFLAGS) $< -o $@

msort260000: msort260000.ml
	$(CC) $(CFLAGS) $< -o $@


clean:
	rm -f $(LOG) $(TARGET) *.o *.cmi *.cmx *~
