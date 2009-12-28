package BackPAN::Index;

use strict;
use warnings;

our $VERSION = '0.37';

use autodie;
use App::Cache 0.37;
use CPAN::DistnameInfo;
use LWP::Simple qw(getstore head is_success);
use Archive::Extract;
use Path::Class ();
use File::stat;
use aliased 'BackPAN::Index::Schema';

use parent qw( Class::Accessor::Fast );

__PACKAGE__->mk_accessors(qw(
    update
    cache_ttl
    debug
    releases_only_from_authors
    cache_dir
    backpan_index_url

    backpan_index schema cache 
));

my %Defaults = (
    backpan_index_url           => "http://www.astray.com/tmp/backpan.txt.gz",
    releases_only_from_authors  => 1,
    debug                       => 0,
    cache_ttl                   => 60 * 60,
);

sub new {
    my $class   = shift;
    my $options = shift;

    $options ||= {};

    # Apply defaults
    %$options = ( %Defaults, %$options );

    my $self  = $class->SUPER::new($options);

    my %cache_opts;
    $cache_opts{ttl}       = $self->cache_ttl;
    $cache_opts{directory} = $self->cache_dir if $self->cache_dir;
    $cache_opts{enabled}   = !$self->update;

    my $cache = App::Cache->new( \%cache_opts );
    $self->cache($cache);

    $self->_update_database();

    return $self;
}

sub _dbh {
    my $self = shift;
    return $self->schema->storage->dbh;
}

sub _log {
    my $self = shift;
    return unless $self->debug;
    print STDERR @_, "\n";
}

sub _update_database {
    my $self = shift;

    # Delay loading it into memory until we need it
    $self->_log("Fetching BackPAN index...");
    $self->_get_backpan_index;
    $self->_log("Done.");

    my $cache = $self->cache;
    my $db_file = Path::Class::file($cache->directory, "backpan.sqlite");

    my $should_update_db;
    if( ! -e $db_file ) {
        $should_update_db = 1;
    }
    elsif( defined $self->update ) {
        $should_update_db = $self->update;
    }
    else {
        # Check the database file before we connect to it.  Connecting will create
        # the file.
        # XXX Should probably just put a timestamp in the DB
        my $db_mtime = $db_file->stat->mtime;
        my $db_age = time - $db_mtime;
        $should_update_db = ($db_age > $cache->ttl);

        # No matter what, update the DB if we got a new index file.
        my $archive_mtime = -e $self->_backpan_index_archive ? $self->_backpan_index_archive->stat->mtime : 0;
        $should_update_db = 1 if $db_mtime < $archive_mtime;
    }

    unlink $db_file if -e $db_file and $should_update_db;

    $self->schema( Schema->connect("dbi:SQLite:dbname=$db_file") );
    $self->_setup_database;

    $should_update_db = 1 if $self->_database_is_empty;

    return unless $should_update_db;

    my $dbh = $self->_dbh;

    $self->_log("Populating database...");
    $dbh->begin_work;

    # Get it out of the hot loop.
    my $only_authors = $self->releases_only_from_authors;

    my $insert_file_sth = $dbh->prepare(q[
        INSERT INTO files
               (path, date, size)
        VALUES (?,      ?,    ?   )
    ]);

    my $insert_release_sth = $dbh->prepare(q[
        INSERT INTO releases
               (file, dist, version, maturity, cpanid, distvname)
        VALUES (?,    ?,    ?,       ?,        ?,      ?        )
    ]);

    my %files;
    open my $fh, $self->_backpan_index_file;
    while( my $line = <$fh> ) {
        chomp $line;
        my ( $path, $date, $size, @junk ) = split ' ', $line;

        if( $files{$path}++ ) {
            $self->_log("Duplicate file $path in index, ignoring");
            next;
        }

        if( !defined $path or !defined $date or !defined $size or @junk ) {
            $self->_log("Bad data read at line $.: $line");
            next;
        }

        next unless $size;
        next if $only_authors and $path !~ m{^authors/};

        $insert_file_sth->execute($path, $date, $size);

        next if $path =~ /\.(readme|meta)$/;

        my $i = CPAN::DistnameInfo->new( $path );

        my $dist = $i->dist;
        next unless $i->dist;
        # strip the .pm package suffix some authors insist on adding
        # this is arguably a bug in CPAN::DistnameInfo.
        $dist =~ s{\.pm$}{}i;

        $insert_release_sth->execute(
            $path,
            $dist,
            $i->version || '',
            $i->maturity,
            $i->cpanid,
            $i->distvname,
        );
    }

    # A view is too slow
    $dbh->do(q[
        INSERT INTO dists
            (name)
            SELECT DISTINCT dist FROM releases
    ]);

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


sub _setup_database {
    my $self = shift;

    my %create_for = (
        files           => <<'SQL',
CREATE TABLE IF NOT EXISTS files (
    path        TEXT            PRIMARY KEY,
    date        INTEGER         NOT NULL,
    size        INTEGER         NOT NULL CHECK ( size >= 0 )
)
SQL
        releases        => <<'SQL',
CREATE TABLE IF NOT EXISTS releases (
    id          INTEGER         PRIMARY KEY,
    file        INTEGER         NOT NULL REFERENCES files,
    dist        TEXT            NOT NULL REFERENCES dists(name),
    version     TEXT            NOT NULL,
    maturity    TEXT            NOT NULL,
    cpanid      TEXT            NOT NULL,
    -- Might be different than dist-version
    distvname   TEXT            NOT NULL
)
SQL

        dists           => <<'SQL',
CREATE TABLE IF NOT EXISTS dists (
    name        TEXT            PRIMARY KEY
)
SQL
);

    my $dbh = $self->_dbh;
    for my $sql (values %create_for) {
        $dbh->do($sql);
    }

    $self->schema->rescan;

    return;
}


sub _get_backpan_index {
    my $self = shift;
    
    my $url = $self->backpan_index_url;

    return if !$self->_backpan_index_has_changed;

    my $status = getstore($url, $self->_backpan_index_archive.'');
    die "Error fetching $url: $status" unless is_success($status);

    my $ae = Archive::Extract->new( archive => $self->_backpan_index_archive );
    $ae->extract( to => $self->_backpan_index_file );

    # If the backpan index age is older than the TTL this prevents us
    # from immediately looking again.
    # XXX Should probably use a "last checked" semaphore file
    $self->_backpan_index_file->touch;

    return;
}


sub _backpan_index_archive {
    my $self = shift;

    my $file = URI->new($self->backpan_index_url)->path;
    $file = Path::Class::file($file)->basename;
    return Path::Class::file($file)->absolute($self->cache->directory);
}


sub _backpan_index_file {
    my $self = shift;

    my $file = $self->_backpan_index_archive;
    $file =~ s{\.[^.]+$}{};

    return Path::Class::file($file);
}


sub _backpan_index_has_changed {
    my $self = shift;

    my $file = $self->_backpan_index_file;
    return 1 unless -e $file;

    my $local_mod_time = stat($file)->mtime;
    my $local_age = time - $local_mod_time;
    return 0 unless $local_age > $self->cache->ttl;

    # We looked, don't have to look again until the ttl is up.
    $self->_backpan_index_file->touch;

    my(undef, undef, $remote_mod_time) = head($self->backpan_index_url);
    return $remote_mod_time > $local_mod_time;
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

    my $rs = $self->schema->resultset("Release");
    $rs = $rs->search({ dist => $dist }) if defined $dist;

    return $rs;
}


sub release {
    my($self, $dist, $version) = @_;

    return $self->releases($dist)->single({ version => $version });
}


sub dists {
    my $self = shift;

    return $self->schema->resultset("Dist");
}


1;


__END__

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

Its a pretty thin wrapper around DBIx::Class returning
L<DBIx::Class::ResultSet> objects which makes it efficient and
flexible.

=head1 METHODS

=head2 new

    my $backpan = BackPAN::Index->new(\%options);

Create a new object representing the BackPAN index.

It will, if necessary, download the BackPAN index and compile it into
a database for efficient storage.  Initial creation is slow, but it
will be cached.

new() takes some options

=head3 update

Because it is rather large, BackPAN::Index caches a copy of the
BackPAN index and builds a local database to speed access.  This flag
controls if the local index is updated.

If true, forces an update of the BACKPAN index.

If false, the index will never be updated even if the cache is
expired.  It will always create a new index if one does not exist.

By default the index is cached and checked for updates according to
C<<$backpan->cache_ttl>>.

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

=head3 cache_dir

Location of the cache directory.

Defaults to whatever L<App::Cache> does.

=head3 backpan_index_url

URL to the BackPAN index.

Defaults to a sensible location.


=head2 files

    my $files = $backpan->files;

Returns a ResultSet representing all the files on BackPAN.

=head2 dists

    my $dists = $backpan->dists;

Returns a ResultSet representing all the distributions on BackPAN.

=head2 dist

    my $dists = $backpan->dist($dist_name);

Returns a single BackPAN::Index::Dist object for $dist_name.

=head2 releases

    my $all_releases  = $backpan->releases();
    my $dist_releases = $backpan->releases($dist_name);

Returns a ResultSet representing all the releases on BackPAN.  If a
$dist_name is given it returns the releases of just one distribution.

=head2 release

    my $release = $backpan->release($dist_name, $version);

Returns a single BackPAN::Index::Release object for the given
$dist_name and $version.


=head1 EXAMPLES

The real power of BackPAN::Index comes from L<DBIx::Class::ResultSet>.
Its very flexible and very powerful but not always obvious how to get
it to do things.  Here's some examples.

    # How many files are on BackPAN?
    my $count = $backpan->files->count;

    # How big is BackPAN?
    my $size = $backpan->files->get_column("size")->sum;

    # What are the names of all the distributions?
    my @names = $backpan->dists->get_column("name")->all;

    # What path contains this release?
    my $path = $backpan->release("Acme-Pony", 1.01)->file->path;


=head1 SEE ALSO

L<DBIx::Class::ResultSet>, L<BackPAN::Index::File>,
L<BackPAN::Index::Release>, L<BackPAN::Index::Dist>

=cut

1;
