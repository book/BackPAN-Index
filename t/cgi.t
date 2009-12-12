#!perl

# Test to make sure CGI.pm is handled correctly

use strict;
use warnings;

use lib 'lib', 't/lib';

use Test::More tests => 4;
use TestUtils;

my $p = new_backpan();

my @releases = $p->releases("CGI");
cmp_ok scalar @releases, '>=', 140;
