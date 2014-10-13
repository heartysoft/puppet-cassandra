#!/bin/bash

#if [ $# -lt 4 ]
#then
#  echo 'usage: cassy-backup.sh -d datadir1 datadir2 -ks keyspace1 keyspace2 -nt /nodetool -u username -pw password -br backupRoot/'
#  exit 1
#fi

echo '============================'
echo 'running cassandra backup'
date
echo '============================'

datadirs=()
keyspaces=()
ntpath=''
user=''
pw=''
param=''
ntpath=nodetool
backupRoot=''

for i in "$@"
do
  case "$i" in
    '-d' )
      param='d' ;;
    '-ks' )
      param='ks';;
    '-nt' )
      param='nt' ;;
    '-u' )
      param='u';;
    '-pw' )
      param='pw';;
    '-br' )
      param='br';;
    * )
      if [ "$param" = 'd' ]
      then
        datadirs=("${datadirs[@]}" $i)
      elif [ "$param" = 'ks' ]
      then
        keyspaces=("${keyspaces[@]}" $i)
      elif [ "$param" = 'nt' ]
      then
        ntpath=$i
      elif [ "$param" = 'u' ]
      then
        user=$i
      elif [ "$param" = 'pw' ]
      then
        pw=$i
      elif [ $param = 'br' ]
      then
        backupRoot=$i
      else
        echo 'usage: cassy-backup.sh -d datadir1 datadir2 -ks keyspace1 keyspace2 -nt /nodetool -u username -pw password -br backupRoot/'
        exit 1
      fi
      ;;
  esac
done

#tar params
tpkses='grep'

if [ $backupRoot"x" = 'x' ]
then
  echo 'backup directory must be provided.'
  echo 'usage: cassy-backup.sh -d datadir1 datadir2 -ks keyspace1 keyspace2 -nt /nodetool -u username -pw password -br backupRoot/'
  exit 1
fi

if [ ${#datadirs[@]} -eq 0 ]
then
  datadirs=('/var/lib/cassandra/data')
fi

for i in "${keyspaces[@]}"
do
  tpkses=$tpkses" -e $i"
done

if [ $tpkses = 'grep' ]
then
  tpkses="tee"
fi

now=$(date +"%Y_%m_%d_%H_%M_%S")

if [ $user"x" = "x" ]
then
  $ntpath clearsnapshot ${keyspaces[@]} 
  $ntpath snapshot ${keyspaces[@]} 
else
  $ntpath --username $user --password $pw clearsnapshot ${keyspaces[@]} 
  $ntpath --username $user --password $pw snapshot ${keyspaces[@]} 
fi

for i in "${datadirs[@]}"
do
  dname=${i////_}
  mkdir -p "$backupRoot/$HOSTNAME/$now"
  find $i -name 'snapshots' | $tpkses | tar -T - -czf "$backupRoot/$HOSTNAME/$now/$dname.tar.gz"
done

echo '============================'
echo 'End of cassandra backup'
echo '============================'
