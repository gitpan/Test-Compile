#!perl -w

use strict;
use warnings;

use Test::Compile;

use Test::More ;
plan skip_all => "Distribution hasn't been built yet" unless -d "blib/lib";

# lib.pl has a dodgy begin block which messes with @INC.
# - that should force it to *only* look in blib/lib for
#   modules.. but it should still compile. See rt72557
#   for more details.
pl_file_ok('t/scripts/lib.pl', 'lib.pl compiles');

done_testing();
