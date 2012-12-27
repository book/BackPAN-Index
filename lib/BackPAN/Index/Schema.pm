package BackPAN::Index::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes({
    "BackPAN::Index" => [qw(Dist File Release)],
});

1;
