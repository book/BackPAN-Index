package Parse::BACKPAN::Packages::Distribution;
use strict;
use base qw( Class::Accessor::Fast );
__PACKAGE__->mk_accessors(qw( prefix date dist version maturity filename
                              cpanid distvname packages ));

1;

__END__

=head1 NAME

Parse::BACKPAN::Packages::Distribution - Represent a distribution on BACKPAN

=head1 SYNOPSIS

  my $p = Parse::BACKPAN::Packages->new();
  my @acme_colours = $p->dists("Acme-Colour");

  print "   CPANID: " . $acme_colours[0]->cpanid . "\n";
  print "     Date: " . $acme_colours[0]->date . "\n";
  print "     Dist: " . $acme_colours[0]->dist . "\n";
  print "Distvname: " . $acme_colours[0]->distvname . "\n";
  print " Filename: " . $acme_colours[0]->filename . "\n";
  print " Maturity: " . $acme_colours[0]->maturity . "\n";
  print "   Prefix: " . $acme_colours[0]->prefix . "\n";
  print "  Version: " . $acme_colours[0]->version . "\n";

=head1 DESCRIPTION

Parse::BACKPAN::Packages::Distribution objects represent distributions
on BACKPAN. They are turned from dists() ordered from oldest to
newest.

=head1 METHODS

=head2 cpanid

The cpanid method returns the PAUSE ID of the author of the distribution.

  print "   CPANID: " . $acme_colours[0]->cpanid . "\n";

=head2 date

The date method returns the data of the release of the distribution, in
UNIX epoch seconds:

  print "     Date: " . $acme_colours[0]->date . "\n";

=head2 dist

The dist method returns the name of the distribution:

  print "     Dist: " . $acme_colours[0]->dist . "\n";

=head2 distvname

The distvname method returns the name of the distribution, hyphen, and
the version:

  print "Distvname: " . $acme_colours[0]->distvname . "\n";

=head2 filename

The filename method returns the filename of the distribution:

  print " Filename: " . $acme_colours[0]->filename . "\n";

=head2 maturity

The maturity method returns the maturity of the distribution:

  print " Maturity: " . $acme_colours[0]->maturity . "\n";

=head2 prefix

The prefix method returns the prefix of the distribution:

  print "   Prefix: " . $acme_colours[0]->prefix . "\n";

=head2 version

The version method returns the version of the distribution:

  print "  Version: " . $acme_colours[0]->version . "\n";

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2005, Leon Brocard

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Parse::BACKPAN::Packages>

