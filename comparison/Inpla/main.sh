#!/bin/bash

bash ./sptestInpla.sh src/fib-38.in
bash ./sptestInpla.sh src/fib-38-reuse.in

bash ./sptestInpla.sh src/ack-stream_3-11.in
bash ./sptestInpla.sh src/ack-stream_3-11-reuse.in

bash ./sptestInpla.sh src/bsort-20000.in
bash ./sptestInpla.sh src/bsort-20000-reuse.in

bash ./sptestInpla.sh src/isort-20000.in
bash ./sptestInpla.sh src/isort-20000-reuse.in

bash ./sptestInpla.sh src/qsort-260000.in
bash ./sptestInpla.sh src/qsort-260000-reuse.in '-Xms 17 -Xmt 0'

bash ./sptestInpla.sh src/msort-260000.in
bash ./sptestInpla.sh src/msort-260000-reuse.in '-Xms 18 -Xmt 0'
