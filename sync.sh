#!/bin/bash
./delete_old http://mirror.organicmaps.app/ dl/mirror.organicmaps.app
WGET_CMD=`./make-wget`
cd dl
echo $WGET_CMD
eval $WGET_CMD
rm $(find . -type f -name "index.html")


