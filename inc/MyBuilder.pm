package MyBuilder;

use strict;
use warnings;

use base 'Module::Build';


sub build_schema {
    local @INC = ("lib", @INC);

    require DBIx::Class::Schema::Loader;
    require BackPAN::Index::Database;
    require File::Temp;
    require DBI;

    my $temp_db = File::Temp->new(EXLOCK => 0);
    my $db = BackPAN::Index::Database->new(
	dbh	=> DBI->connect("dbi:SQLite:dbname=$temp_db")
    );
    $db->create_tables;

    DBIx::Class::Schema::Loader::make_schema_at(
	# We need to customize the schema to only load certain classes.
	# There's no way to do that or tell it not to make the schema.
	# So make a throw away one.
	'BackPAN::Index::SchemaThrowaway',
	{
	    # We'll write our own POD
	    generate_pod        => 0,

	    result_namespace 	=> '+BackPAN::Index',
	    use_namespaces   	=> 1,

	    # Protect us from naming style changes
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
	    },

	    debug 		=> 0,

	    dump_directory	=> 'lib',
	},
	[
	    $db->dsn, undef, undef
        ]
    );

    # Throw the generated schema away.
    unlink "lib/BackPAN/Index/SchemaThrowaway.pm";
}

sub ACTION_code {
    my $self = shift;

    $self->build_schema;

    return $self->SUPER::ACTION_code(@_);
}

1;
