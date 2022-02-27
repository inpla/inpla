#!/bin/bash

bash ./sptestInpla.sh src/fib-38.in
bash ./sptestInpla.sh src/fib-38-reuse.in

bash ./sptestInpla.sh src/ack-stream_3-11.in
bash ./sptestInpla.sh src/ack-stream_3-11-reuse.in

bash ./sptestInpla.sh src/bsort-40000.in
bash ./sptestInpla.sh src/bsort-40000-reuse.in

bash ./sptestInpla.sh src/isort-40000.in
bash ./sptestInpla.sh src/isort-40000-reuse.in

bash ./sptestInpla.sh src/qsort-800000.in
bash ./sptestInpla.sh src/qsort-800000-reuse.in '-Xms 18 -Xmt 0'

bash ./sptestInpla.sh src/msort-800000.in
bash ./sptestInpla.sh src/msort-800000-reuse.in '-Xms 18 -Xmt 0'
