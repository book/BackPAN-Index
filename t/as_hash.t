#!/usr/bin/perl -w

use strict;
use warnings;
use lib 't/lib';

use TestUtils;

use Test::More;

my $b = new_backpan();

{
    my $dist = $b->dists->search(undef, { order_by => "random()", rows => 1 })->first;
    note("Dist is @{[$dist->name]}");

    is_deeply $dist->as_hash, {
        name    => $dist->name
    };

    my $release = $dist->releases->search(undef, { order_by => "random()" })->first;
    note("Release is @{[$release->distvname]}");

    is_deeply $release->as_hash, {
        dist            => $release->dist,
        version         => $release->version,
        cpanid          => $release->cpanid,
        date            => $release->date,
        path            => $release->path,
        maturity        => $release->maturity
    };

    is "$release", $release->distvname,  "Release stringifies to distvname";

    my $file = $release->file;
    note("File is @{[$release->path]}");

    is_deeply $file->as_hash, {
        path            => $file->path,
        size            => $file->size,
        date            => $file->date
    };
}


done_testing();
