#!/usr/bin/perl -w

use strict;
use warnings;
use lib 't/lib';

use TestUtils;

use Test::More;

my $b = new_backpan();

subtest "distribution name normalization" => sub {
    my $v200 = $b->release("URIC", '2.00');
    my $v201 = $b->release("URIC", '2.01');
    my $v202 = $b->release("URIC", '2.02');

    is $v200->filename,  'uri-2.00.tar.gz';
    is $v200->distvname, 'uri-2.00';

    is $v201->filename,  'uri-2.01.tar.gz';
    is $v201->distvname, 'uri-2.01';

    is $v202->filename,  'URIC-2.02.tar.gz';
    is $v202->distvname, 'URIC-2.02';

    for my $release ($v200, $v201, $v202) {
        is $release->dist, 'URIC', $release->path." has been normalized";
    }
};


subtest "per release dist normalization" => sub {
    my $release = $b->release("Bi", '0.01');
    is $release->filename, '-0.01.tar.gz';
    is $release->cpanid,   'MARCEL';
    is $release->dist,     'Bi';
    is $release->version,  '0.01';
    is $release->distvname,'Bi-0.01';
};


done_testing;
