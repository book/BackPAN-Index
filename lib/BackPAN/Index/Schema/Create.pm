package BackPAN::Index::Schema::Create;

use Mouse;

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

1;
