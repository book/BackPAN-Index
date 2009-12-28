package BackPAN::Index::Dist;

use strict;
use warnings;

use parent qw(DBIx::Class::Core);

use CLASS;

use overload
  q[""]         => sub { $_[0]->name },
  fallback      => 1;

CLASS->table("distributions");
CLASS->add_columns("name");
CLASS->set_primary_key("name");
CLASS->has_many( releases => "BackPAN::Index::Release", "dist" );

1;

__END__

=head1 NAME

BackPAN::Index::Dist - Representing a distribution on BackPAN

=head1 SYNOPSIS

Use through BackPAN::Index.

=head1 DESCRIPTION

An object representing a distribution on BackPAN.  A distribution is
made up of releases.

=head2 releases

    my $releases = $dist->releases;

A ResultSet of this distribution's releases.

=head2 name

    my $dist_name = $dist->name;

Name of the distribution.

=head1 SEE ALSO

L<BackPAN::Index>

=cut

1;
