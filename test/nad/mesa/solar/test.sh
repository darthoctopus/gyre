#!/bin/bash
#
# File     : test.sh
# Purpose  : GYRE testing script

. test_support

# Settings

EXEC=./gyre

IN_FILE=gyre.in
OUT_FILE=summary.h5

LABEL="MESA model for Sun (non-adiabatic, diffusion vs. Eddington approxiation)"

# Do the tests

run_gyre $EXEC $IN_FILE "$LABEL"
if [ $? -ne 0 ]; then
    exit 1;
fi

check_output $OUT_FILE '' --delta=3e-13
if [ $? -ne 0 ]; then
    exit 1;
fi

# Clean up output files

rm -f $OUT_FILE

# Finish

echo " ...succeeded"
