#!perl -w
use strict;
use warnings;
use Test::More tests => 1;
use Test::Compile;

# cheap emulation
$^O = 'VMS';
pl_file_ok('t/scripts/subdir/success.pl', 'success.pl compiles');
