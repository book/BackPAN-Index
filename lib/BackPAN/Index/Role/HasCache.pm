package BackPAN::Index::Role::HasCache;

use Types::Standard qw(InstanceOf);
use Moo::Role;

has cache =>
  is		=> 'ro',
  isa		=> InstanceOf['App::Cache'],
  required 	=> 1,
  default	=> sub {
      require App::Cache;
      return App::Cache->new({ application => "BackPAN::Index" });
  }
;

1;
