package BackPAN::Index::Schema;

use strict;
use warnings;

use parent qw(DBIx::Class::Schema::Loader);

use CLASS;

CLASS->loader_options(
    result_namespace 	=> '+BackPAN::Index',
    use_namespaces   	=> 1,
    naming           	=> 'v7',
    inflect_singular 	=> sub {
	my $word = shift;

	# Work around bug in Linua::EN::Inflect::Phrase
	if( $word =~ /^(first|second|third|fourth|fifth|sixth)_/ ) {
	    $word =~ s{s$}{};
	    return $word;
	}
	else {
	    return;
	}
    }
);


=head1 NAME

BackPAN::Index::Schema - DBIx::Class schema class

=head1 SYNOPSIS

No user servicable parts inside

=head1 DESCRIPTION

No user servicable parts inside

=cut

1;
