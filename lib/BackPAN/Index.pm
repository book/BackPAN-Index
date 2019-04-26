package BackPAN::Index;

use Moo;
with 'BackPAN::Index::Role::Log', 'BackPAN::Index::Role::HasCache';

our $VERSION = '0.42';

use autodie;
use CPAN::DistnameInfo 0.09;
use BackPAN::Index::Schema;
use Types::Standard qw(InstanceOf Bool Int Str HashRef);
use Types::URI qw(Uri);

use namespace::clean;

has update =>
  is		=> 'ro',
  isa		=> Bool,
  default	=> 0;

has cache_ttl =>
  is		=> 'ro',
  isa		=> Int,
  default	=> 60 * 60;

has releases_only_from_authors =>
  is		=> 'ro',
  isa		=> Bool,
  default	=> 1;

has normalize =>
  is            => 'ro',
  isa           => Bool,
  default       => 1;

has backpan_index_url =>
  is		=> 'ro',
  isa		=> Uri,
  coerce        => 1,
  builder       => 'default_backpan_index_url';

sub default_backpan_index_url {
    return "http://gitpan.integra.net/backpan-index.gz";
}

has backpan_index =>
  is		=> 'ro',
  isa		=> InstanceOf['BackPAN::Index::IndexFile'],
  lazy		=> 1,
  default	=> sub {
      my $self = shift;

      require BackPAN::Index::IndexFile;
      return BackPAN::Index::IndexFile->new(
	  cache 	=> $self->cache,
	  index_url	=> $self->backpan_index_url
      );
  };

has cache_dir =>
  is		=> 'ro',
  isa		=> Str
;

has '+cache' =>
  is		=> 'rw',
  required	=> 0,
  lazy		=> 1,
  default	=> sub {
      my $self = shift;

      my %cache_opts;
      $cache_opts{ttl}       = $self->cache_ttl;
      $cache_opts{directory} = $self->cache_dir if $self->cache_dir;
      $cache_opts{enabled}   = !$self->update;

      require App::Cache;
      return App::Cache->new( \%cache_opts );
  }
;

has db =>
  is		=> 'ro',
  isa		=> InstanceOf['BackPAN::Index::Database'],
  handles	=> [qw(schema)],
  lazy		=> 1,
  default	=> sub {
      my $self = shift;

      require BackPAN::Index::Database;
      return BackPAN::Index::Database->new(
	  cache => $self->cache
      );
  };

has normalize_dist_names =>
  is            => 'ro',
  isa           => HashRef,
  default       => sub {
      return {
          uri                             => 'URIC',
          'Webservice-Google-Suggest'     => 'WebService-Google-Suggest'
      };
  };

has normalize_releases =>
  is            => 'ro',
  isa           => HashRef,
  default       => sub {
      return {
          # This is 箆-0.01.  I went with the unidecoded name instead
          # because I don't want to mess with Unicode right now.
          # Maybe later.
          'authors/id/M/MA/MARCEL/-0.01.tar.gz'         => {
              dist      => 'Bi',
              version   => '0.01',
          }
      };
  };

sub BUILD {
    my $self = shift;

    $self->_update_database();

    return $self;
}

sub _update_database {
    my $self = shift;

    # Delay loading it into memory until we need it
    $self->backpan_index->get_index if $self->backpan_index->should_index_be_updated;

    my $should_update_db =
      $self->update 				||
      $self->db->should_update_db 		||
      $self->_index_archive_newer_than_db;

    my $db_file = $self->db->db_file;
    unlink $db_file if -e $db_file and $should_update_db;

    $self->db->create_tables if $should_update_db;

    $self->_populate_database if $should_update_db || $self->_database_is_empty;

    return;
}

sub _index_archive_newer_than_db {
    my $self = shift;

    return $self->db->db_mtime < $self->backpan_index->index_archive_mtime;
}

sub _populate_database {
    my $self = shift;

    my $dbh = $self->db->dbh;

    $self->_log("Populating database...");
    $dbh->begin_work;

    # Get them out of the hot loop.
    my $only_authors     = $self->releases_only_from_authors;
    my $should_normalize = $self->normalize;
    my $normalize_dist_names = $self->normalize_dist_names;
    my $normalize_releases   = $self->normalize_releases;

    my $insert_file_sth = $dbh->prepare(q[
        INSERT INTO files
               (path, date, size)
        VALUES (?,      ?,    ?   )
    ]);

    my $insert_release_sth = $dbh->prepare(q[
        INSERT INTO releases
               (path, dist, version, date, size, maturity, cpanid, distvname)
        VALUES (?,    ?,    ?,       ?,    ?,    ?,        ?,      ?        )
    ]);

    my $insert_dist_sth = $dbh->prepare(q[
        INSERT INTO dists
               (name, num_releases,
                first_release,  first_date,  first_author,
                latest_release, latest_date, latest_author)
        VALUES (?,    ?,
                ?,              ?,           ?,
                ?,              ?,           ?)
    ]);

    my %dists;
    my %files;
    open my $fh, $self->backpan_index->index_file;
    while( my $line = <$fh> ) {
        my %release;
        chomp $line;
        @release{"path", "date", "size", "junk"} = split ' ', $line;

        if( $files{$release{path}}++ ) {
            $self->_log("Duplicate file $release{path} in index, ignoring");
            next;
        }

        if( !defined $release{path} or
            !defined $release{date} or
            !defined $release{size} or
            $release{junk}
        ) {
            $self->_log("Bad data read at line $.: $line");
            next;
        }

        next unless $release{size};
        next if $only_authors and $release{path} !~ m{^authors/};

        $insert_file_sth->execute(@release{"path", "date", "size"});

        next if $release{path} =~ /\.(readme|meta)$/;

        my $i = CPAN::DistnameInfo->new( $release{path} );

        $release{dist}      = $i->dist    || '';
        $release{version}   = $i->version || '';
        $release{maturity}  = $i->maturity;
        $release{cpanid}    = $i->cpanid;
        $release{distvname} = $i->distvname;

        # Normalize distribution names
        if( $should_normalize ) {
            $release{dist} = $normalize_dist_names->{$release{dist}} || $release{dist};

            if( my $normalize_release = $normalize_releases->{$release{path}} ) {
                for my $key (keys %$normalize_release) {
                    $release{$key} = $normalize_release->{$key};
                }

                # Recalculate the distvname if the dist or version changed
                $release{distvname} = $release{dist}.'-'.$release{version} if
                  defined $normalize_release->{dist} or
                  defined $normalize_release->{version};
            }
        }

        next unless $release{dist};

        $insert_release_sth->execute(
            @release{
                "path", "dist", "version", "date", "size",
                "maturity", "cpanid", "distvname"
            }
        );


        # Update aggregate data about dists
        my $distdata = ($dists{$release{dist}} ||= { name => $release{dist} });

        if( !defined $distdata->{first_release} ||
            $release{date} < $distdata->{first_date} )
        {
            $distdata->{first_release} = $release{path};
            $distdata->{first_author}  = $release{cpanid};
            $distdata->{first_date}    = $release{date};
        }

        if( !defined $distdata->{latest_release} ||
            $release{date} > $distdata->{latest_date} )
        {
            $distdata->{latest_release} = $release{path};
            $distdata->{latest_author}  = $release{cpanid};
            $distdata->{latest_date}    = $release{date};
        }

        $distdata->{num_releases}++;
    }

    for my $dist (values %dists) {
        $insert_dist_sth->execute(
            @{$dist}
              {qw(name num_releases
                  first_release  first_date  first_author
                  latest_release latest_date latest_author
              )}
        );
    }

    # Add indexes after inserting so as not to slow down the inserts
    $self->db->create_indexes;

    $dbh->commit;

    $self->_log("Done.");

    return;
}


sub _database_is_empty {
    my $self = shift;

    return 1 unless $self->files->count;
    return 1 unless $self->releases->count;
    return 0;
}


sub file {
    my($self, $path) = @_;
    return $self->files->single({ path => $path });
}

sub files {
    my $self = shift;
    return $self->schema->resultset('File');
}


sub dist {
    my($self, $dist) = @_;

    return $self->dists->single({ name => $dist });
}


sub releases {
    my($self, $dist) = @_;

    return $self->schema->resultset("Release") unless defined $dist;
    return $self->schema->resultset("Release")->search({ dist => $dist });
}


sub release {
    my($self, $dist, $version) = @_;

    return $self->releases($dist)->single({ version => $version });
}


sub dists {
    my $self = shift;

    return $self->schema->resultset("Dist");
}


=head1 NAME

BackPAN::Index - An interface to the BackPAN index

=head1 SYNOPSIS

    use BackPAN::Index;
    my $backpan = BackPAN::Index->new;

    # These are all DBIx::Class::ResultSet's
    my $files    = $backpan->files;
    my $dists    = $backpan->dists;
    my $releases = $backpan->releases("Acme-Pony");

    # Use DBIx::Class::ResultSet methods on them
    my $release = $releases->single({ version => '1.23' });

    my $dist = $backpan->dist("Test-Simple");
    my $releases = $dist->releases;

=head1 DESCRIPTION

This downloads, caches and parses the BackPAN index into a local
database for efficient querying.

It's a pretty thin wrapper around DBIx::Class returning
L<DBIx::Class::ResultSet> objects which makes it efficient and
flexible.

The Comprehensive Perl Archive Network (CPAN) is a very useful
collection of Perl code. However, in order to keep CPAN relatively
small, authors of modules can delete older versions of modules to only
let CPAN have the latest version of a module. BackPAN is where these
deleted modules are backed up. It's more like a full CPAN mirror, only
without the deletions. This module provides an index of BackPAN and
some handy methods.

=head1 METHODS

=head2 new

    my $backpan = BackPAN::Index->new(\%options);

Create a new object representing the BackPAN index.

It will, if necessary, download the BackPAN index and compile it into
a database for efficient storage.  Initial creation is slow, but it
will be cached.

new() takes some options

=head3 update

Because it is rather large, C<BackPAN::Index> caches a copy of the
BackPAN index and builds a local database to speed access.  This flag
controls if the local index is updated.

If true, forces an update of the BACKPAN index.

If false, the index will never be updated even if the cache is
expired.  It will always create a new index if one does not exist.

By default the index is cached and checked for updates according to
C<< $backpan->cache_ttl >>.

=head3 cache_ttl

How many seconds before checking for an updated index.

Defaults to an hour.

=head3 debug

If true, debug messages will be printed.

Defaults to false.

=head3 releases_only_from_authors

If true, only files in the C<authors> directory will be considered as
releases.  If false any file in the index may be considered for a
release.

Defaults to true.

=head3 normalize

If true, various fixes and normalizations of distribution names and
version numbers will be performed.  This will result in a more usable
index, but it will no longer be a canonical representation of the
files on BackPAN.

Defaults to true.

=head3 normalize_dist_names

A hash ref of distribution names and what to rename them to.

For example, C<< { uri => "URIC" } >> would ensure that a release like
"uri-2.00.tar.gz" is counted as being part of the URIC distribution.

Defaults to something sensible.

=head3 normalize_releases

A hash ref.  Keys are release paths.  Values are hash refs of what
parts of the release to change.

For example, here C<< SOMEONE/Foo-Bar-.01.tar.gz >> is given a version
of 0.01 instead of .01.  The release's distvname will also be changed to
C<< Foo-Bar-0.01 >>.

    'authors/id/S/SO/SOMEONE/Foo-Bar-.01.tar.gz' => {
        version         => '0.01',
    }


=head3 cache_dir

Location of the cache directory.

Defaults to whatever L<App::Cache> does.

=head3 backpan_index_url

URL to the BackPAN index.

Defaults to a sensible location.


=head2 files

    my $files = $backpan->files;

Returns a C<ResultSet> representing all the files on BackPAN.

=head2 files_by

    my $files = $backpan->files_by($cpanid);
    my @files = $backpan->files_by($cpanid);

Returns all the files by a given C<< $cpanid >>.

Returns either a list of C<BackPAN::Index::Files> or a C<ResultSet>.

=cut

sub files_by {
    my $self = shift;
    my $cpanid = shift;

    return $self->files->search({ "releases.cpanid" => $cpanid }, { join => "releases" });
}

=head2 dists

    my $dists = $backpan->dists;

Returns a C<ResultSet> representing all the distributions on BackPAN.

=head2 dist

    my $dists = $backpan->dist($dist_name);

Returns a single C<BackPAN::Index::Dist> object for C<< $dist_name >>.

=head2 dists_by

    my $dists = $backpan->dists_by($cpanid);
    my @dists = $backpan->dists_by($cpanid);

Returns the dists which contain at least one release by the given
C<< $cpanid >>.

Returns either a C<ResultSet> or a list of the Dists.

=cut

sub dists_by {
    my $self = shift;
    my $cpanid = shift;

    return $self->dists->search({ "releases.cpanid" => $cpanid }, { join => "releases", distinct => 1 });
}


=head2 dists_changed_since

    my $dists = $backpan->dists_changed_since($time);

Returns a C<ResultSet> of distributions which have had releases at or after
after C<< $time >>.

=cut

sub dists_changed_since {
    my $self = shift;
    my $time = shift;

    return $self->dists->search( latest_date => \">= $time" );
}

=head2 releases

    my $all_releases  = $backpan->releases();
    my $dist_releases = $backpan->releases($dist_name);

Returns a C<ResultSet> representing all the releases on BackPAN.  If a
C<< $dist_name >> is given it returns the releases of just one distribution.

=head2 release

    my $release = $backpan->release($dist_name, $version);

Returns a single C<BackPAN::Index::Release> object for the given
C<< $dist_name >> and C<< $version >>.

=head2 releases_by

    my $releases = $backpan->releases_by($cpanid);
    my @releases = $backpan->releases_by($cpanid);

Returns all the releases of a single author.

Returns either a list of Releases or a C<ResultSet> representing those releases.

=cut

sub releases_by {
    my $self   = shift;
    my $cpanid = shift;

    return $self->releases->search({ cpanid => $cpanid });
}


=head2 releases_since

    my $releases = $backpan->releases_since($time);

Returns a C<ResultSet> of releases which were released at or after C<< $time >>.

=cut

sub releases_since {
    my $self = shift;
    my $time = shift;

    return $self->releases->search( date => \">= $time" );
}


=head1 EXAMPLES

The real power of C<BackPAN::Index> comes from L<DBIx::Class::ResultSet>.
It's very flexible and very powerful but not always obvious how to get
it to do things.  Here are some examples.

    # How many files are on BackPAN?
    my $count = $backpan->files->count;

    # How big is BackPAN?
    my $size = $backpan->files->get_column("size")->sum;

    # What are the names of all the distributions?
    my @names = $backpan->dists->get_column("name")->all;

    # What path contains this release?
    my $path = $backpan->release("Acme-Pony", 1.01)->path;

    # Get all the releases of Moose ordered by version
    my @releases = $backpan->dist("Moose")->releases
                                          ->search(undef, { order_by => "version" });

=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>

=head1 COPYRIGHT

Copyright 2009, Michael G Schwern

=head1 LICENSE

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<DBIx::Class::ResultSet>, L<BackPAN::Index::File>,
L<BackPAN::Index::Release>, L<BackPAN::Index::Dist>

Repository:  L<http://github.com/acme/parse-backpan-packages>
Bugs:        L<http://rt.cpan.org/Public/Dist/Display.html?Name=Parse-BACKPAN-Packages>

=cut

1;
