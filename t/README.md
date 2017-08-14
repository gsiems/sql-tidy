
# testing

## Files and directories

### input

The "input" directory contains the set of sql scripts to test.

### expected

The "expected" directory contains files that are formatted in the
desired, or expected, format. There may not be an expected file for all
entries in the "input" directory. If there is no corresponding file in
the "expected" directory then it is to be assumed that the input script
is already in the desired output format.

### failed

The "failed" directory contains the results for those files that failed
to generate the expected result.

### prove.pl

prove.pl runs each sql file in the input directory and compares the
result to the expected result to determine if the formatting was
successful or not. If the comparison fails then the results are written
to the "failed" directory.
