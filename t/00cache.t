#!perl

# A test to clear and populate the cache so subsequent tests run faster

use strict;
use warnings;
use Test::More tests => 4;
use lib "t/lib";
use_ok("Parse::BACKPAN::Packages");

use TestUtils;

# Clear out any leftover cache
TestUtils::clear_cache();

# Populate the cache
my $p = new_backpan();
isa_ok( $p, "Parse::BACKPAN::Packages" );
cmp_ok( $p->size, '>=', 5_597_434_696, "backpan is at least 5.6G" );

my $files = $p->files;
cmp_ok( scalar( keys %$files ), '>=', 105_996 );
