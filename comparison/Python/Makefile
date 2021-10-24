COMMAND = python3
#TARGET  = ack3-11.py fib38.py bsort-40000.py isort-40000.py qsort-800000.py msort-800000.py
TARGET  = fib38.py bsort-40000.py isort-40000.py qsort-800000.py msort-800000.py
BENCHMARK  = bash ../tools/sptest_scripts.sh
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(COMMAND) '$(TARGET)'

clean:
	rm -f $(LOG) *~
