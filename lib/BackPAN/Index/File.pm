package BackPAN::Index::File;

use strict;
use warnings;

use File::Basename qw(basename);
use CLASS;

sub url {
    my $self = shift;
    return "http://backpan.cpan.org/" . $self->prefix;
}

sub filename {
    my $self = shift;
    return basename $self->prefix;
}

1;

__END__

=head1 NAME

BackPAN::Index::File - Represent a file on BackPAN

=head1 SYNOPSIS

  my $b = BackPAN::Index->new();
  my $file = $b->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
  print "  Date: " . $file->date . "\n";
  print "Prefix: " . $file->prefix . "\n";
  print "  Size: " . $file->size . "\n";
  print "   URL: " . $file->url . "\n";

=head1 DESCRIPTION

BackPAN::Index::File objects represent files on BackPAN.

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

=head2 filename

Just the filename part of the prefix.

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2005, Leon Brocard

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<BackPAN::Index>

