#!/usr/bin/bash
dir=(OCaml Haskell SML Python Inpla)
for d in ${dir[@]} ; do
#    echo "cd $d; make clean; make; cd ..";
#          cd $d; make clean; make; cd ..
    echo "cd $d; make; cd ..";
          cd $d; make; cd ..
done
