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

use base qw( Class::Accessor::Fast );

__PACKAGE__->mk_accessors(qw(
    no_cache cache_dir backpan_index_url backpan_index only_authors
    schema cache debug
));

my %Defaults = (
    backpan_index_url => "http://www.astray.com/tmp/backpan.txt.gz",
);

sub new {
    my $class   = shift;
    my $options = shift;

    $options->{only_authors} = 1 unless exists $options->{only_authors};
    $options->{debug}        = 1 if $ENV{PARSE_BACKPAN_PACKAGES_DEBUG};

    my $self  = $class->SUPER::new($options);

    $self->backpan_index_url($Defaults{backpan_index_url})
      unless $self->backpan_index_url;

    my %cache_opts;
    $cache_opts{ttl}       = 60 * 60;
    $cache_opts{directory} = $self->cache_dir if $self->cache_dir;
    $cache_opts{enabled}   = !$self->no_cache;

    my $cache = App::Cache->new( \%cache_opts );
    $self->cache($cache);

    my $dbfile = Path::Class::file($cache->directory, "backpan.sqlite");

    my $dbage = -e $dbfile ? time - $dbfile->stat->mtime : 2**30;
    my $should_update_db = !-e $dbfile || $self->no_cache || ($dbage > $cache_opts{ttl});
    unlink $dbfile if -e $dbfile and $should_update_db;

    $self->schema( Schema->connect("dbi:SQLite:dbname=$dbfile") );
    $self->_update_database() if $should_update_db;

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

    $self->_setup_database;

    my $dbh = $self->_dbh;

    $self->_log("Populating database...");
    $dbh->begin_work;

    open my $fh, $self->_backpan_index_file;
    while( my $line = <$fh> ) {
        chomp $line;
        my ( $prefix, $date, $size ) = split ' ', $line;

        next unless $size;
        next if $prefix !~ m{^authors/} and $self->only_authors;

        $dbh->do(q[
            REPLACE INTO files
                   (prefix, date, size)
            VALUES (?,      ?,    ?   )
        ], undef, $prefix, $date, $size);

        next if $prefix =~ /\.(readme|meta)$/;

        my $file_id = $dbh->last_insert_id("", "", "files", "");

        my $i = CPAN::DistnameInfo->new( $prefix );

        my $dist = $i->dist;
        next unless $i->dist;
        # strip the .pm package suffix some authors insist on adding
        # this is arguably a bug in CPAN::DistnameInfo.
        $dist =~ s{\.pm$}{}i;

        $dbh->do(q{
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

    $dbh->commit;

    $self->_log("Done.");

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

        distributions   => <<'SQL',
CREATE VIEW IF NOT EXISTS distributions AS
    SELECT DISTINCT dist as name FROM releases
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

    return $file;
}


sub _backpan_index_has_changed {
    my $self = shift;

    my $file = $self->_backpan_index_file;
    return 1 unless -e $file;

    my(undef, undef, $mod_time) = head($self->backpan_index_url);
    return $mod_time > stat($self->_backpan_index_file)->mtime;
}


sub files {
    my $self = shift;
    return $self->schema->resultset('File');
}


sub distribution {
    my($self, $dist) = @_;

    return $self->distributions->single({ name => $dist });
}


sub releases {
    my($self, $dist) = @_;

    my $rs = $self->schema->resultset("Release");
    $rs->search({ dist => $dist }) if defined $dist;

    return $rs;
}


sub release {
    my($self, $dist, $version) = @_;

    return $self->releases($dist)->single({ version => $version });
}


sub distributions {
    my $self = shift;

    return $self->schema->resultset("Distribution");
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
    my $dists    = $backpan->distributions;
    my $releases = $backpan->releases("Acme-Pony");

    # Use DBIx::Class::ResultSet methods on them
    my $release = $releases->single({ version => '1.23' });

    my $dist = $backpan->distribution("Test-Simple");
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

=head2 files

    my $files = $backpan->files;

Returns a ResultSet representing all the files on BackPAN.

=head2 distributions

    my $dists = $backpan->distributions;

Returns a ResultSet representing all the distributions on BackPAN.

=head2 distribution

    my $dists = $backpan->distribution($dist_name);

Returns a single BackPAN::Index::Distribution object for $dist_name.

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
    my @names = $backpan->distributions->get_column("name")->all;


=head1 SEE ALSO

L<DBIx::Class::ResultSet>

=cut

1;
