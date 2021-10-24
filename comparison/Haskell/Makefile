CC      = stack ghc
CFLAGS  = -O2
BENCHMARK  = bash ../tools/sptest_commands.sh
TARGET  = ack3-11 fib38 bsort-40000 isort-40000 qsort-800000 msort-800000
#TARGET  = ack3-11
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(TARGET)

ack3-11: ack3-11.hs
	$(CC) -- $(CFLAGS) $<

fib38: fib38.hs
	$(CC) -- $(CFLAGS) $<

bsort-40000: bsort-40000.hs
	$(CC) -- $(CFLAGS) $<

isort-40000: isort-40000.hs
	$(CC) -- $(CFLAGS) $<

qsort-800000: qsort-800000.hs
	$(CC) -- $(CFLAGS) $<

msort-800000: msort-800000.hs
	$(CC) -- $(CFLAGS) $<


clean:
	rm -f $(LOG) $(TARGET) *.o *.hi *~
