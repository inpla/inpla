#!/bin/bash

bash ./sptestInpla.sh src/nqueen-12.in '-Xmt 6 -foptimise-tail-calls'
bash ./sptestInpla.sh src/nqueen-12-reuse.in '-Xmt 6'

bash ./sptestInpla.sh src/fib-38.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/fib-38-reuse.in

bash ./sptestInpla.sh src/ack-stream_3-11.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/ack-stream_3-11-reuse.in

bash ./sptestInpla.sh src/bsort-20000.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/bsort-20000-reuse.in

bash ./sptestInpla.sh src/isort-20000.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/isort-20000-reuse.in

bash ./sptestInpla.sh src/qsort-260000.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/qsort-260000-reuse.in

bash ./sptestInpla.sh src/msort-260000.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/msort-260000-reuse.in

bash ./sptestInpla.sh src/qsort-800000.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/qsort-800000-reuse.in

bash ./sptestInpla.sh src/msort-800000.in '-foptimise-tail-calls'
bash ./sptestInpla.sh src/msort-800000-reuse.in
