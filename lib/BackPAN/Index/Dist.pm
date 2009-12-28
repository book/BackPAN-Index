package BackPAN::Index::Dist;

use strict;
use warnings;

use parent qw(DBIx::Class::Core);

use CLASS;

use overload
  q[""]         => sub { $_[0]->name },
  fallback      => 1;

use BackPAN::Index::Role::AsHash;

sub data_methods {
    return qw(name);
}

sub authors {
    my $self = shift;

    return $self->releases->search(undef, { distinct => 1 })->get_column("cpanid")->all;
}


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

=head2 authors

    my @authors = $dist->authors;

Return the CPANIDs which made releases of this $dist, in no particular order.

=head2 as_hash

    my $data = $dist->as_hash;

Returns a hash ref containing the data inside C<$dist>.


=head1 SEE ALSO

L<BackPAN::Index>

=cut

1;
