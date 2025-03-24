#!/bin/bash
#
# File     : test.sh
# Purpose  : gyre_tides testing script

. test_support

# Settings

EXEC=./gyre_tides

IN_FILE=gyre_tides.in
OUT_FILE=summary.h5

LABEL="MESA model for slowly pulsating B-type star (tides)"

# Do the tests

run_gyre $EXEC $IN_FILE "$LABEL"
if [ $? -ne 0 ]; then
    exit 1;
fi

check_output $OUT_FILE '' --delta=1e-15
if [ $? -ne 0 ]; then
    exit 1;
fi

# Clean up output files

rm -f $OUT_FILE

# Finish

echo " ...succeeded"
