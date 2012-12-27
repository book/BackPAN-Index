use utf8;
package BackPAN::Index::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes({
    "BackPAN::Index" => [qw(Dist File Release)],
});


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-12-27 01:39:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nuF+3I0+Ir1lFmKHYH8kug


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
