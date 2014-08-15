#!/usr/bin/perl

use strict;
use warnings;
use v5.12;
use autodie;
use File::Find::Rule;
use IO::Zlib;
use Path::Tiny;

my $backpan = path(shift)->absolute;
my $outfile = path(shift)->absolute;

# Build in a temp file to avoid serving a half built index while building
my $tmpfile = Path::Tiny->tempfile;
my $out = IO::Zlib->new($tmpfile.'', "wb9") || die $!;

chdir $backpan;
foreach my $filename (sort File::Find::Rule->new->file->in(".")) {
    my $stat = path($filename)->stat;
    say $out join " ", $filename, $stat->mtime, $stat->size;
}
$out->close;

# Put it in place.
$tmpfile->move($outfile);

# Make extra sure the web server can read it.
$outfile->chmod(0644);


=head1 NAME

create_backpan_index.pl - Create the BackPAN index file

=head1 SYNOPSIS

    create_backpan_index.pl path/to/backpan path/to/index.gz

=head1 DESCRIPTION

Creates the index used by BackPAN::Index.  Intended to be used on a
BackPAN server.

Each line is space delimited information about a file.

    filepath mtime size

=cut
