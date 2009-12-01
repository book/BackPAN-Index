#!perl

use strict;
use warnings;

use lib 'lib', 't/lib';

use Test::More tests => 3;
use TestUtils;

my $p = new_backpan();

my $dists = $p->dists;
cmp_ok scalar @$dists, '>=', 21911;

my %dists = map { $_ => 1 } @$dists;
ok $dists{"Acme-Pony"};

# Pick a distribution at random, it should have releases.
my $dist = $dists->[rand @$dists];
my @releases = $p->distributions($dist);
is $releases[0]->dist, $dist, "found releases for $dist";

1;
