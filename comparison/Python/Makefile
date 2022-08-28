COMMAND = python3
TARGET  = dummy.py nqueen-12.py ack3-11.py fib-38.py bsort-20000.py isort-20000.py qsort-260000.py msort-260000.py
BENCHMARK  = bash ../tools/sptest_scripts.sh
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(COMMAND) '$(TARGET)'

clean:
	rm -f $(LOG) *~
