CC      = stack ghc
CFLAGS  = -O2
BENCHMARK  = bash ../tools/sptest_commands.sh
TARGET  = ack3-11 fib38 bsort-20000 isort-20000 qsort-260000 msort-260000
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(TARGET)

ack3-11: ack3-11.hs
	$(CC) -- $(CFLAGS) $<

fib38: fib38.hs
	$(CC) -- $(CFLAGS) $<

bsort-20000: bsort-20000.hs
	$(CC) -- $(CFLAGS) $<

isort-20000: isort-20000.hs
	$(CC) -- $(CFLAGS) $<

qsort-260000: qsort-260000.hs
	$(CC) -- $(CFLAGS) $<

msort-260000: msort-260000.hs
	$(CC) -- $(CFLAGS) $<


clean:
	rm -f $(LOG) $(TARGET) *.o *.hi *~
