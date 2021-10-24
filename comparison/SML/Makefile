COMMAND = sml
TARGET  = ack3-11.sml fib38.sml bsort-40000.sml isort-40000.sml qsort-800000.sml msort-800000.sml
BENCHMARK  = bash ../tools/sptest_scripts.sh
LOG = log.txt


.PHONY: all

all: $(LOG)

$(LOG): $(TARGET)
	$(BENCHMARK) $(COMMAND) '$(TARGET)'

clean:
	rm -f $(LOG) *~
