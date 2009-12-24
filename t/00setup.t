#!perl

# A test to clear and populate the cache so subsequent tests run faster

use strict;
use warnings;
use Test::More tests => 4;
use lib "t/lib";
use_ok("BackPAN::Index");

use TestUtils;

# Clear out any leftover cache
TestUtils::clear_cache();

# Populate the cache
diag("Fetching the BackPAN index and creating the database. This may take a while.");
my $p = new_backpan();
isa_ok( $p, "BackPAN::Index" );
cmp_ok( $p->files->get_column("size")->sum, '>=', 5_597_434_696, "backpan is at least 5.6G" );
cmp_ok( $p->files->count, '>=', 105_996 );
