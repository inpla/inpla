#!/bin/bash
# $1: name list of commands
# ex: ./sptest_commands.sh fib38 bsort-40000


# repeat and waittimes
ct=10
waittime=5

# etc
log="log.txt"

# -------------------------------------------------
function mywait() {
    for w in $(seq 1 $waittime) ; do
	echo -n "."
	sleep 1
    done
}

function gettime() {
  rm -f _result.txt
  for i in $(seq 1 $ct) ; do
      (time $1) 2>> _result.txt
      echo 
      echo "Done ($i/$ct)"
      if [[ $(($i + 1)) -le $ct ]]; then
	  mywait
	  echo 'Restart'
      fi      
  done
  echo
  echo
  logtime=`grep real _result.txt | cut -f2 | sed -e "s/\(.*\)m\(.*\)s/\1 \2/" | awk -F' ' '{print ($1*60+$2)}'`
  echo "execution time"
  echo "$logtime"

  # for return value
 res=`echo $logtime | awk 'BEGIN{r=0;c=0} {r=r+$0;c++} END{print r/c}'`
   rm -f _result.txt
}


rm -f $log

echo '' >> $log
echo "$ct" | awk -F',' '{printf("%-27s| avg. time over %d runs (sec)\n","",$1)}' >> $log
echo '===========================+=============================' >> $log

for f in "$@"; do
  command="$f"
  echo -n "Cooling CPU in $waittime sec"
  mywait
  echo ' The experiment starts.'
  echo "------------------"   
  echo "$f"
  gettime "./$f"
  echo "Average ${res}sec"
  echo "$command,$res" | awk -F',' '{printf("%-27s| %.2f\n",$1,$2)}' >> $log
done

echo
cat $log

