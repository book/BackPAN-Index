package TestUtils;

use strict;
use warnings;

use File::Spec;
use File::Path;
use Parse::BACKPAN::Packages;

use base "Exporter";
our @EXPORT = qw(new_backpan);

sub cache_dir {
    return File::Spec->rel2abs("t/cache");
}

sub clear_cache {
    rmtree cache_dir();
}

sub new_backpan {
    my $cache_dir = File::Spec->rel2abs("t/cache");
    return Parse::BACKPAN::Packages->new( { cache_dir => $cache_dir } );
}

1;
