#!perl

use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 4;
use TestUtils;

my $p = new_backpan();

my $dists = $p->distributions;
cmp_ok $dists->count, '>=', 21911;

ok $p->distribution("Acme-Pony");

# Pick a distribution at random, it should have releases.
{
    my $dist = $dists->[rand @$dists];
    my $releases = $p->releases($dist);
    is $releases->first->dist, $dist, "found releases for $dist";
}

1;
