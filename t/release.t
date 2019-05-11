#!perl

use strict;
use warnings;

use lib 't/lib';

use Test::More;
use TestUtils;

my $Backpan;
subtest "Setting up BackPAN" => sub {
    $Backpan = new_backpan();
    isa_ok $Backpan, "BackPAN::Index";
};

subtest "accessors" => sub {
    # Specifically pick a release with a subdirectory to test
    # short_path() edge case.
    my $release = $Backpan->release("HTTP-Client", 1.43);

    is $release->cpanid,        "LINC";
    is $release->date,          1124983921;
    is $release->dist,          "HTTP-Client";
    isa_ok $release->dist, "BackPAN::Index::Dist";
    is $release->distvname,     "HTTP-Client-1.43";
    is $release->path,          "authors/id/L/LI/LINC/HTTP/HTTP-Client-1.43.tar.gz";
    isa_ok $release->path, "BackPAN::Index::File";
    is $release->short_path,    "LINC/HTTP/HTTP-Client-1.43.tar.gz";
    is $release->filename,      "HTTP-Client-1.43.tar.gz";
    is $release->maturity,      "released";
    is $release->version,       1.43;
};

done_testing;
