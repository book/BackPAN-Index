package Parse::BACKPAN::Packages;

use strict;
use warnings;

our $VERSION = '0.36';

use App::Cache 0.37;
use CPAN::DistnameInfo;
use LWP::UserAgent;
use Compress::Zlib;
use Path::Class ();
use Parse::BACKPAN::Packages::File;
use Parse::BACKPAN::Packages::Release;
use DBI;
use DBD::SQLite;

use base qw( Class::Accessor::Fast );

__PACKAGE__->mk_accessors(qw(
    no_cache cache_dir backpan_index_url backpan_index
    only_authors dbh
));

my %Defaults = (
    backpan_index_url => "http://www.astray.com/tmp/backpan.txt.gz",
);

sub new {
    my $class   = shift;
    my $options = shift;

    $options->{only_authors} = 1 unless exists $options->{only_authors};

    my $self  = $class->SUPER::new($options);

    $self->backpan_index_url($Defaults{backpan_index_url})
      unless $self->backpan_index_url;

    my %cache_opts;
    $cache_opts{ttl}       = 60 * 60;
    $cache_opts{directory} = $self->cache_dir if $self->cache_dir;
    $cache_opts{enabled}   = !$self->no_cache;

    my $cache = App::Cache->new( \%cache_opts );

    $self->backpan_index(
        $cache->get_code( 'backpan_index', sub { $self->_get_backpan_index } )
    );

    my $dbfile = Path::Class::file($cache->directory, "backpan.sqlite");

    my $dbage = -e $dbfile ? time - $dbfile->stat->mtime : 2**30;
    my $should_update_db = !-e $dbfile || $self->no_cache || ($dbage > $cache_opts{ttl});
    $self->dbh(
        DBI->connect(
            "dbi:SQLite:dbname=$dbfile", "", "",
            {RaiseError => 1}
        )
    );
    $self->_update_database() if $should_update_db;

    return $self;
}


sub _update_database {
    my $self = shift;

    my $index = $self->backpan_index;

    $self->_setup_database;

    $self->dbh->begin_work;
    foreach my $line ( split "\n", $index ) {
        my ( $prefix, $date, $size ) = split ' ', $line;

        next unless $size;
        next if $prefix !~ m{^authors/} and $self->only_authors;

        $self->dbh->do(q[
            REPLACE INTO files
                   (prefix, date, size)
            VALUES (?,      ?,    ?   )
        ], undef, $prefix, $date, $size);

        next if $prefix =~ /\.(readme|meta)$/;

        my $file_id = $self->dbh->last_insert_id("", "", "files", "");

        my $i = CPAN::DistnameInfo->new( $prefix );

        my $dist = $i->dist;
        next unless $i->dist;
        # strip the .pm package suffix some authors insist on adding
        # this is arguably a bug in CPAN::DistnameInfo.
        $dist =~ s{\.pm$}{}i;

        $self->dbh->do(q{
            REPLACE INTO releases
                   (file, dist, version, maturity, cpanid, distvname)
            VALUES (?,    ?,    ?,       ?,        ?,      ?        )
            }, undef,
            $prefix,
            $dist,
            $i->version || '',
            $i->maturity,
            $i->cpanid,
            $i->distvname,
        );
    }

    $self->dbh->commit;

    return;
}


sub _setup_database {
    my $self = shift;

    my %create_for = (
        files           => <<'SQL',
CREATE TABLE IF NOT EXISTS files (
    prefix      TEXT            PRIMARY KEY,
    date        INTEGER         NOT NULL,
    size        INTEGER         NOT NULL CHECK ( size >= 0 )
)
SQL
        releases        => <<'SQL',
CREATE TABLE IF NOT EXISTS releases (
    id          INTEGER         PRIMARY KEY,
    file        INTEGER         NOT NULL REFERENCES files,
    dist        TEXT            NOT NULL,
    version     TEXT            NOT NULL,
    maturity    TEXT            NOT NULL,
    cpanid      TEXT            NOT NULL,
    -- Might be different than dist-version
    distvname   TEXT            NOT NULL
)
SQL
    );

    for my $table (qw(files releases)) {
        $self->dbh->do($create_for{$table});
    }
}


sub _get_backpan_index {
    my $self = shift;
    
    my $url = $self->backpan_index_url;
    my $ua  = LWP::UserAgent->new;
    $ua->env_proxy();
    $ua->timeout(180);
    my $response = $ua->get($url);

    die "Error fetching $url" unless $response->is_success;

    my $gzipped = $response->content;
    my $data = Compress::Zlib::memGunzip($gzipped);
    die "Error uncompressing data from $url" unless $data;

    return $data;
}


sub files {
    my $self = shift;

    my $files = $self->dbh->selectall_hashref(
        "SELECT * FROM files",
        "prefix",
        { Slice => {} }
    );

    for my $value (values %$files) {
        # Nice performance cheat, eh?
        bless $value, "Parse::BACKPAN::Packages::File";
    }

    return $files;
}


sub file {
    my ( $self, $prefix ) = @_;

    my $files = $self->dbh->selectall_arrayref(
        "SELECT * FROM files WHERE prefix = ?",
        { Slice => {} },
        $prefix
    );

    my $file = $files->[0];
    bless $file, "Parse::BACKPAN::Packages::File";
    return $file;
}


sub releases {
    my($self, $dist) = @_;

    my $releases = $self->dbh->selectall_arrayref(q[
            SELECT  *
            FROM    releases
            WHERE   dist = ?
        ],
        { Slice => {} },
        $dist
    );

    bless $_, "Parse::BACKPAN::Packages::Release" for @$releases;
    return @$releases;
}


sub distributions {
    my $self = shift;

    # For backwards compatibilty when releases() was distributions()
    return $self->releases(shift) if @_;

    my $dists = $self->dbh->selectcol_arrayref(
        "SELECT DISTINCT dist FROM releases"
    );
    return $dists;
}

sub distributions_by {
    my ( $self, $author ) = @_;
    return unless $author;

    my $dists = $self->dbh->selectcol_arrayref(q[
             SELECT DISTINCT dist
             FROM   releases
             WHERE  cpanid = ?
             ORDER BY dist
        ],
        undef,
        $author
    );

    return @$dists;
}

sub authors {
    my $self     = shift;

    my $authors = $self->dbh->selectcol_arrayref(q[
        SELECT DISTINCT cpanid
        FROM     releases
        ORDER BY cpanid
    ]);

    return @$authors;
}

sub size {
    my $self = shift;

    my $size = $self->dbh->selectcol_arrayref(q[
        SELECT SUM(size) FROM files
    ]);

    return $size->[0];
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

  # see Parse::BACKPAN::Packages::Release
  my @acme_colours = $p->releases("Acme-Colour");
  
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

  my $distributions = $p->distributions;

The distributions method returns an array ref of the names of all the
distributions in BackPAN.

=head2 releases

The releases method returns a list of objects representing all
the different releases of a distribution:

  # see Parse::BACKPAN::Packages::Release
  my @acme_colours = $p->releases("Acme-Colour");

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
L<Parse::BACKPAN::Packages::Release>, L<Parse::CPAN::Packages>.
