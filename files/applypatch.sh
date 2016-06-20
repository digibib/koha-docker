#!/bin/bash
# applypatch.sh: Simple bash library to apply patches to docker image, 
# either diff patches or bugzilla patches
# diff patches should be created with:
#   diff -Naur orig new > file.patch

cleanup() {
    rv=$?
    echo "$MSG"
    if [ -n $RETVAL ];
    then
      exit $RETVAL
    else
      exit $rv
    fi
}

usage() { 
  echo -e "\nUsage:\n$0 [-p|--patch] [-b|--bugid] \n"
  exit 1
}

applyBugId() {
  MSG=`wget -qO- 'http://bugs.koha-community.org/bugzilla3/attachment.cgi?id=$1' | git apply -v`
  RETVAL=$?
}

applyPatch() {
  local FILE=$1
  local RES

  if [ -f $FILE ];
  then
    patch -p0 -N --dry-run -i $FILE > /dev/null     # dry-run first
    RETVAL=$?
    if [ $RETVAL -eq 0 ];                           # all good?
    then
      MSG="`patch -p0 -N < $FILE` ------------> OK" # apply the patch
    else
      MSG="'Patch error: ${RES}'"
      RETVAL=1
    fi
  else
    MSG="'Patchfile does not exist'"
    RETVAL=1
  fi

}

case "$1" in
    "")
    usage
    ;;
  --patch|-p)
    shift
    applyPatch $1
    shift
    ;;
  --bugid|-b)
    shift
    applyBug $1
    shift
    ;;
  --help|-h)
    usage
    ;;
esac

trap "cleanup" INT TERM EXIT
