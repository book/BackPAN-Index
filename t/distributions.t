#!perl

use strict;
use warnings;

use lib 'lib', 't/lib';

use Test::More tests => 4;
use TestUtils;

my $p = new_backpan();

my $dists = $p->distributions;
cmp_ok scalar @$dists, '>=', 21911;

my %dists = map { $_ => 1 } @$dists;
ok $dists{"Acme-Pony"};

# Pick a distribution at random, it should have releases.
{
    my $dist = $dists->[rand @$dists];
    my @releases = $p->releases($dist);
    is $releases[0]->dist, $dist, "found releases for $dist";
}


# Ensure distributions($dist) still works
{
    my $dist = $dists->[rand @$dists];
    is_deeply [$p->distributions($dist)], [$p->releases($dist)],
              "distributions($dist) backwards compatibility";
}


1;
