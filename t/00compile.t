#!/usr/bin/env perl

use strict;
use warnings;

use Test::Compile;

my $test = Test::Compile->new();
$test->all_files_ok($test->all_pm_files());
$test->done_testing();
