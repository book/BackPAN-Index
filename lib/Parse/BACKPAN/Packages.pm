package Parse::BACKPAN::Packages;
use strict;
use warnings;
use App::Cache;
use CPAN::DistnameInfo;
use Compress::Zlib;
use IO::File;
use IO::Zlib;
use LWP::UserAgent;
use Parse::BACKPAN::Packages::File;
use Parse::BACKPAN::Packages::Distribution;
use base qw( Class::Accessor::Fast );
__PACKAGE__->mk_accessors(qw( files dists_by no_cache ));
our $VERSION = '0.36';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    if ( !$self->no_cache ) {
        my $cache = App::Cache->new( { ttl => 60 * 60 } );
        $self->files(
            $cache->get_code( 'files', sub { $self->_init_files() } ) );
        $self->dists_by(
            $cache->get_code( 'dists_by', sub { $self->_init_dists_by() } ) );
    } else {
        $self->files( $self->_init_files() );
        $self->dists_by( $self->_init_dists_by() );
    }

    return $self;
}

sub _init_files {
    my $self = shift;
    my $files;

    my $data;
    my $url = "http://www.astray.com/tmp/backpan.txt.gz";
    my $ua  = LWP::UserAgent->new;
    $ua->env_proxy();
    $ua->timeout(180);
    my $response = $ua->get($url);

    if ( $response->is_success ) {
        my $gzipped = $response->content;
        $data = Compress::Zlib::memGunzip($gzipped);
        die "Error uncompressing data from $url" unless $data;
    } else {
        die "Error fetching $url";
    }

    foreach my $line ( split "\n", $data ) {
        my ( $prefix, $date, $size ) = split ' ', $line;
        next unless $size;
        my $file = Parse::BACKPAN::Packages::File->new(
            {   prefix => $prefix,
                date   => $date,
                size   => $size,
            }
        );
        $files->{$prefix} = $file;
    }
    return $files;
}

sub file {
    my ( $self, $prefix ) = @_;
    return $self->files->{$prefix};
}

sub distributions {
    my ( $self, $name ) = @_;
    my @files;

    while ( my ( $prefix, $file ) = each %{ $self->files } ) {
        my $prefix = $file->prefix;
        next unless $prefix =~ m{\/$name-};
        next if $prefix =~ /\.(readme|meta)$/;
        push @files, $file;
    }

    @files = sort { $a->date <=> $b->date } @files;

    my @dists;
    foreach my $file (@files) {
        my $i = CPAN::DistnameInfo->new( $file->prefix );
        my $dist = $i->dist || '';
        next unless $dist eq $name;
        my $d = Parse::BACKPAN::Packages::Distribution->new(
            {   prefix    => $file->prefix,
                date      => $file->date,
                dist      => $dist,
                version   => $i->version,
                maturity  => $i->maturity,
                filename  => $i->filename,
                cpanid    => $i->cpanid,
                distvname => $i->distvname,
            }
        );
        push @dists, $d;
    }

    return @dists;
}

sub distributions_by {
    my ( $self, $author ) = @_;
    return unless $author;

    my $dists_by = $self->dists_by;

    my @dists = @{ $dists_by->{$author} || [] };
    return sort @dists;
}

sub authors {
    my $self     = shift;
    my $dists_by = $self->dists_by;
    return sort keys %$dists_by;
}

sub _init_dists_by {
    my ($self) = shift;
    my @files;

    while ( my ( $prefix, $file ) = each %{ $self->files } ) {
        my $prefix = $file->prefix;
        next if $prefix =~ /\.(readme|meta)$/;
        push @files, $file;
    }

    @files = sort { $a->date <=> $b->date } @files;

    my $dist_by;
    foreach my $file (@files) {
        my $i = CPAN::DistnameInfo->new( $file->prefix );
        my ( $dist, $cpanid ) = ( $i->dist, $i->cpanid );
        next unless $dist && $cpanid;

        $dist_by->{$cpanid}{$dist}++;
    }

    my %dists_by = map { $_ => [ keys %{ $dist_by->{$_} } ] } keys %$dist_by;

    return \%dists_by;
}

sub size {
    my $self = shift;
    my $size;

    foreach my $file ( values %{ $self->files } ) {
        $size += $file->size;
    }
    return $size;
}

1;

__END__

=head1 NAME

Parse::BACKPAN::Packages - Provide an index of BACKPAN

=head1 SYNOPSIS

  use Parse::BACKPAN::Packages;
  my $p = Parse::BACKPAN::Packages->new();
  print "BACKPAN is " . $p->size . " bytes\n";

  my @filenames = keys %$p->files;

  # see Parse::BACKPAN::Packages::File
  my $file = $p->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
  print "That's " . $file->size . " bytes\n";

  # see Parse::BACKPAN::Packages::Distribution
  my @acme_colours = $p->distributions("Acme-Colour");
  
  my @authors = $p->authors;
  my @acmes = $p->distributions_by('LBROCARD');

=head1 DESCRIPTION

The Comprehensive Perl Archive Network (CPAN) is a very useful
collection of Perl code. However, in order to keep CPAN relatively
small, authors of modules can delete older versions of modules to only
let CPAN have the latest version of a module. BACKPAN is where these
deleted modules are backed up. It's more like a full CPAN mirror, only
without the deletions. This module provides an index of BACKPAN and
some handy functions.

The data is fetched from the net and cached for an hour.

=head1 METHODS

=head2 new

The constructor downloads a ~1M index file from the web and parses it,
so it might take a while to run:

  my $p = Parse::BACKPAN::Packages->new();

By default it caches the file locally for one hour. If you do not
want this caching then you can pass in:

  my $p = Parse::BACKPAN::Packages->new( { no_cache => 1 } );

=head2 authors

The authors method returns a list of all the authors. This is meant so
that you can pass them into the distributions_by method:

  my @authors = $p->authors;

=head2 distributions

The distributions method returns a list of objects representing all
the different versions of a distribution:

  # see Parse::BACKPAN::Packages::Distribution
  my @acme_colours = $p->distributions("Acme-Colour");

=head2 distributions_by

The distributions_by method returns a list of distribution names
representing all the distributions that an author has uploaded:

  my @acmes = $p->distributions_by('LBROCARD');

=head2 file

The file method finds metadata relating to a file:

  # see Parse::BACKPAN::Packages::File
  my $file = $p->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
  print "That's " . $file->size . " bytes\n";

=head2 files

The files method returns a hash reference where the keys are the
filenames of the files on CPAN and the values are
Parse::BACKPAN::Packages::File objects:

  my @filenames = keys %$p->files;

=head2 size

The size method returns the sum of all the file sizes in BACKPAN:

  print "BACKPAN is " . $p->size . " bytes\n";

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2005-9, Leon Brocard

=head1 LICENSE

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPAN::DistInfoname>, L<Parse::BACKPAN::Packages::File>,
L<Parse::BACKPAN::Packages::Distribution>, L<Parse::CPAN::Packages>.
