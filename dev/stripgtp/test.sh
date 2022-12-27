#!/bin/bash

echo STRIP
echo -----
for n in *.gtp *.GTP; do echo -n "$n ";  ./strip < $n; done
echo ------
echo STRIP2
echo ------
for n in *.gtp *.GTP; do echo -n "$n ";  ./strip2 $n; done

