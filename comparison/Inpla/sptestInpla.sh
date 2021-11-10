#!/bin/bash
# $1: the source file name
# $2: options
# example: ./sptestInpla.sh A3_10.in '-x 100000'


# repeat and waittime
ct=10
waittime=5

max_threads=9

# options
source=$1
inpla_seq='inplaSeq'
inpla_para='inplaPara'
opt=$2
#dir_source='prog/'
dir_make='../../'
path_source="$dir_source$source"
fname=`echo $1 | sed -e s'|.*/\(.*\)|\1|'`

log="log-${fname}.txt"


# main ------------------------------------------------------
if [ -z $1 ]; then
  echo "Usage: ./sptestInpla.sh filename option"
  exit
fi

if [ ! -e $path_source ]; then
  echo "$path_source is not found."
  exit
fi

if [ ! -e $inpla_seq -a ! -e "${inpla_seq}.exe" ]; then
  echo "Now making Inpla in the non-threaded version as '$inpla_seq'."
  make -C "$dir_make" clean
  make -C "$dir_make"
if [ -e 'inpla.exe' ]; then
  inpla_seq="${inpla_seq}.exe"
  mv ../../inpla.exe ./$inpla_seq
else
  mv ../../inpla ./$inpla_seq
fi
fi

if [ ! -e $inpla_para -a ! -e "${inpla_para}.exe" ]; then
  echo "Now making Inpla in the multi-threaded version as '$inpla_para'."
  make -C "$dir_make" clean
  make -C "$dir_make" thread
if [ -e 'inpla.exe' ]; then
  inpla_para="${inpla_para}.exe"
  mv ../../inpla.exe ./$inplla_para
else
  mv ../../inpla ./$inpla_para
fi
fi


# -------------------------------------------------
function mywait() {
    for w in $(seq 1 $waittime) ; do
	echo -n "."
	sleep 1
    done
}

function gettime() {
  # $1: the execution command
  rm -f _result.txt
  for i in $(seq 1 $ct) ; do
      (time $1) 2>> _result.txt
      echo 
      echo -n "Done ($i/$ct)"
      if [[ $(($i + 1)) -le $ct ]]; then
	  mywait
	  echo 'Restart'
      fi      
  done
  echo
  echo
  logtime=`grep real _result.txt | cut -f2 | sed -e "s/\(.*\)m\(.*\)s/\1 \2/" | awk -F' ' '{print ($1*60+$2)}'`
  echo "Execution time"
  echo "$logtime"
  
  # for return value
  res=`echo "$logtime\n" | awk 'BEGIN{r=0;c=0} {r=r+$0;c++} END{print r/c}'` 
 rm -f _result.txt
}

function puts_header() {
  # $1: the name of the log file
  # $2: a program name
  # ex: puts_header $log

  local alog
  alog=$1

  echo '' >> $alog
  echo "$2,$ct" | awk -F',' '{printf("%-27s| avg. time over %d runs (sec)\n",$1,$2)}' >> $alog
  echo '===========================+=============================' >> $alog
}

function do_experiment() {
  # $1: execution command
  # $2: the header string to put the logfile
  # ex: do_experiment "$inpla -f $source $opt_special $opt"
  echo -n 'Cooling CPU'
  mywait
  echo
  echo "------------------"   
  echo "$1"
  gettime "$1"
  echo "Average ${res}sec"
  echo "$2,$res" | awk -F',' '{printf("%-27s| %.2f\n",$1,$2)}' >> $log
}



# clear the previous log
rm -f $log


puts_header $log "$source $opt"

# Execution in sequential
do_experiment "./$inpla_seq -f $path_source $opt" "non-thread"

# Execution in parallel
for ((thread=1; thread<=max_threads; thread++))
do 
  do_experiment "./$inpla_para -f $path_source $opt -t $thread" "-t $thread"
done

echo
cat $log

