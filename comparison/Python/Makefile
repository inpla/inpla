COMMAND = python3
TARGET  = dummy.py ack3-11.py fib38.py bsort-40000.py isort-40000.py qsort-260000.py msort-260000.py
BENCHMARK  = bash ../tools/sptest_scripts.sh
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(COMMAND) '$(TARGET)'

clean:
	rm -f $(LOG) *~
