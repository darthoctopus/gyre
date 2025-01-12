#!/bin/bash
#
# File     : test.sh
# Purpose  : GYRE testing script

. test_support

# Settings

EXEC=./gyre

IN_FILE=gyre.in
OUT_FILE=summary.h5

LABEL="analytic polytrope model (n_poly=5,1)"

# Do the tests

run_gyre $EXEC $IN_FILE "$LABEL"
if [ $? -ne 0 ]; then
    exit 1;
fi

check_output $OUT_FILE
if [ $? -ne 0 ]; then
    exit 1;
fi

# Clean up output files

rm -f $OUT_FILE

# Finish

echo " ...succeeded"
