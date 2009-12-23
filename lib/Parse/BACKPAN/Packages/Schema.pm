package Parse::BACKPAN::Packages::Schema;

use strict;
use warnings;

use parent qw(DBIx::Class::Schema::Loader);

use CLASS;

CLASS->loader_options(
    moniker_map => sub {
        my $table = shift;
        my $class = ucfirst $table;
        $class =~ s/s$//;

        return $class;
    },
    result_namespace => '+Parse::BACKPAN::Packages',
    use_namespaces => 1,
);


=head1 NAME

Parse::BACKPAN::Packages::Schema - DBIx::Class schema class

=head1 SYNOPSIS

No user servicable parts inside

=head1 DESCRIPTION

No user servicable parts inside

=cut

1;
