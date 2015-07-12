#!/bin/bash
# applypatch.sh: Simple bash library to apply patches to koha docker image, 
# either diff patches or bugzilla patches
# diff patches should be created with:
#   git diff --no-index orig new > file.patch
# New patching method for database updates:
#   http://wiki.koha-community.org/wiki/Database_updates#Using_the_new_update_procedure

trap "cleanup" INT TERM EXIT

cleanup() {
    rv=$?
    echo -e "$MSG"
    if [ -n $RETVAL ];
    then
      exit $RETVAL
    else
      exit $rv
    fi
}

usage() { 
  echo -e "\nUsage:\n$0 [-p|--patch] [-b|--bugid] patchdir \n"
  exit 1
}

applyBugId() {
  local FILE=$1
  local DIR=$2
  MSG=`cd $2 && echo yes | git bz apply $1`
  RETVAL=$?
  if [ ! $RETVAL -eq 0 ]; then exit 1; fi

}

applyPatch() {
  local FILE=$1
  local DIR=$2
  local RES

  if [ -f $FILE ];
  then
    echo "CMD: patch -d ${DIR:-.} -p1 -N --verbose --ignore-whitespace --reject-file=/tmp/reject -i $FILE"
    RES=`patch -d ${DIR:-.} -p1 -N --verbose --ignore-whitespace \
         --reject-file=/tmp/reject -i $FILE`
    RETVAL=$?
    if [ $RETVAL -eq 0 ];                                                 # all good?
    then
      MSG="-------------------> OK"
    else
      MSG="Patch error: ${RES}"
      MSG+="\nRejected file:"
      MSG+="\n-------\n"
      MSG+="$([ -f /tmp/reject ] && cat /tmp/reject)"
      MSG+="\n-------\n"
      exit $RETVAL
    fi
  else
    MSG="'ERROR: ${FILE} does not exist'"
    exit 1
  fi

}

case "$1" in
    "")
    usage
    ;;
  --patch|-p)
    shift
    applyPatch $1 $2
    shift
    ;;
  --bugid|-b)
    shift
    applyBugId $1 $2
    shift
    ;;
  --help|-h)
    usage
    ;;
esac


