#!perl

use strict;
use warnings;

use lib 't/lib';
use TestUtils;

use Test::More tests => 1;

my $p = new_backpan();

my @not_authors = grep !/^authors/, keys %{$p->files};
is_deeply \@not_authors, [], "only_authors only sees authors/";
