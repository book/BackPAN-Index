package BackPAN::Index::Database;

use Mouse;
with 'BackPAN::Index::Role::HasCache';

use BackPAN::Index::Types;
use Path::Class;

has db_file =>
  is		=> 'ro',
  isa		=> 'Path::Class::File',
  lazy		=> 1,
  coerce	=> 1,
  default	=> sub {
      my $self = shift;
      return Path::Class::File->new($self->cache->directory, "backpan.sqlite").'';
  }
;

# This is denormalized for performance, its read-only anyway
has create_tables_sql =>
  is		=> 'ro',
  isa		=> 'HashRef[Str]',
  default 	=> sub {
      return {
        files           => <<'SQL',
CREATE TABLE IF NOT EXISTS files (
    path        TEXT            NOT NULL PRIMARY KEY,
    date        INTEGER         NOT NULL,
    size        INTEGER         NOT NULL CHECK ( size >= 0 )
)
SQL
        releases        => <<'SQL',
CREATE TABLE IF NOT EXISTS releases (
    path        TEXT            NOT NULL PRIMARY KEY REFERENCES files,
    dist        TEXT            NOT NULL REFERENCES dists,
    date        INTEGER         NOT NULL,
    size        TEXT            NOT NULL,
    version     TEXT            NOT NULL,
    maturity    TEXT            NOT NULL,
    distvname   TEXT            NOT NULL,
    cpanid      TEXT            NOT NULL
)
SQL

        dists           => <<'SQL',
CREATE TABLE IF NOT EXISTS dists (
    name                TEXT            NOT NULL PRIMARY KEY,
    first_release       TEXT            NOT NULL REFERENCES releases,
    latest_release      TEXT            NOT NULL REFERENCES releases,
    first_date          INTEGER         NOT NULL,
    latest_date         INTEGER         NOT NULL,
    first_author        TEXT            NOT NULL,
    latest_author       TEXT            NOT NULL,
    num_releases        INTEGER         NOT NULL
)
SQL
    }
  };

sub create_tables {
    my $self = shift;
    my $dbh  = shift;

    for my $sql (values %{$self->create_tables_sql}) {
        $dbh->do($sql);
    }

    return;
}


sub db_file_exists {
    my $self = shift;
    return -e $self->db_file;
}

sub should_update_db {
    my $self = shift;

    return 1 if !$self->db_file_exists;
    return 1 if $self->cache_is_old;
    return 0;
}

sub cache_is_old {
    my $self = shift;

    return 1 if $self->db_age > $self->cache->ttl;
    return 0;
}

sub db_mtime {
    my $self = shift;

    # XXX Should probably just put a timestamp in the DB
    return $self->db_file->stat->mtime;
}

sub db_age {
    my $self = shift;

    return time - $self->db_mtime;
}

1;
