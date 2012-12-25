package BackPAN::Index::Role::HasCache;

use Mouse::Role;

use BackPAN::Index::Types;

has cache =>
  is		=> 'ro',
  isa		=> 'App::Cache',
  required 	=> 1
;

1;
