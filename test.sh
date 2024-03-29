#!/bin/bash

cd `dirname $0`
exitcode=0

if [ ! -d "`dirname $0`/tests/testbox" ]; then
  box install
fi

box stop name="html-importtests"
box start directory="./tests/" serverConfigFile="./server-tests.json"
box testbox run verbose=false || exitcode=1
box stop name="html-importtests"

exit $exitcode
