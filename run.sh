#!/bin/bash
file=./Galaksija.bit
if [ "$1" != "" ]; then file=$1; fi
cat << EOF | jtag
cable usbblaster
detect
pld load ${file}
EOF

