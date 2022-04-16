CC      = ocamlopt
CFLAGS  = 
BENCHMARK  = bash ../tools/sptest_commands.sh
#TARGET  = ack3_11 fib38 bsort40000 isort40000 qsort800000 msort800000
TARGET  = ack3_11 fib38 bsort40000 isort40000
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(TARGET)

ack3_11: ack3_11.ml
	$(CC) $(CFLAGS) $< -o $@

fib38: fib38.ml
	$(CC) $(CFLAGS) $< -o $@

bsort40000: bsort40000.ml
	$(CC) $(CFLAGS) $< -o $@

isort40000: isort40000.ml
	$(CC) $(CFLAGS) $< -o $@

qsort800000: qsort-800000.ml
	$(CC) $(CFLAGS) $< -o $@

msort800000: msort-800000.ml
	$(CC) $(CFLAGS) $< -o $@


clean:
	rm -f $(LOG) $(TARGET) *.o *.cmi *.cmx *~
