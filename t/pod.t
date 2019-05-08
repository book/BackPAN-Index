#!perl -T

use warnings;
use strict;

use Test::More;
use Class::Load qw(try_load_class);

plan skip_all => "Author test" unless $ENV{AUTHOR_TESTING};
my $min_tp = 1.14;
try_load_class('Test::Pod', {-version => $min_tp})
     or plan skip_all => "Test::Pod $min_tp required for testing POD";
 Test::Pod::all_pod_files_ok();
