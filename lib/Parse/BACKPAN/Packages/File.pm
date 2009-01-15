package Parse::BACKPAN::Packages::File;
use strict;
use base qw( Class::Accessor::Fast );
__PACKAGE__->mk_accessors(qw(prefix date size));

sub url {
  my $self = shift;
  return "http://backpan.cpan.org/" . $self->prefix;
}

1;

__END__

=head1 NAME

Parse::BACKPAN::Packages::File - Represent a file on BACKPAN

=head1 SYNOPSIS

  my $p = Parse::BACKPAN::Packages->new();
  my $file = $p->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
  print "  Date: " . $file->date . "\n";
  print "Prefix: " . $file->prefix . "\n";
  print "  Size: " . $file->size . "\n";
  print "   URL: " . $file->url . "\n";

=head1 DESCRIPTION

Parse::BACKPAN::Packages::File objects represent files on BACKPAN.

=head1 METHODS

=head2 date

The date method returns the upload date of the file, in UNIX epoch seconds:

  print "  Date: " . $file->date . "\n";

=head2 prefix

The prefix method returns the prefix of the file:

  print "Prefix: " . $file->prefix . "\n";

=head2 size

The size method returns the size of the file in bytes:

  print "  Size: " . $file->size . "\n";

=head2 url

The url method returns a URL to the file:

  print "   URL: " . $file->url . "\n";

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2005, Leon Brocard

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Parse::BACKPAN::Packages>

