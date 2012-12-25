package BackPAN::Index::Database;

use Mouse;
use BackPAN::Index::Types;
use Path::Class;

has cache =>
  is		=> 'ro',
  isa		=> 'App::Cache',
  required 	=> 1
;

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
