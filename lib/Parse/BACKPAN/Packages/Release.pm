package Parse::BACKPAN::Packages::Release;

use strict;
use warnings;

use CLASS;

sub date {
    my $self = shift;
    return $self->file->date;
}

sub filename {
    my $self = shift;
    return $self->file->filename;
}

sub prefix {
    my $self = shift;
    return $self->file->prefix;
}

1;

__END__

=head1 NAME

Parse::BACKPAN::Packages::Release - A single release of a distribution

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

Parse::BACKPAN::Packages::Release objects represent releases,
individual tarballs/zip files, of a distribution on BACKPAN.

For example, Acme-Pony-1.2.3.tar.gz is a release of the Acme-Pony
distribution.

=head1 METHODS

=head2 cpanid

The cpanid method returns the PAUSE ID of the author of the release.

  print "   CPANID: " . $acme_colours[0]->cpanid . "\n";

=head2 date

The date method returns the date of the release, in UNIX epoch
seconds:

  print "     Date: " . $acme_colours[0]->date . "\n";

=head2 dist

The dist method returns the name of the distribution:

  print "     Dist: " . $acme_colours[0]->dist . "\n";

=head2 distvname

The distvname method returns the name of the distribution, hyphen, and
the version:

  print "Distvname: " . $acme_colours[0]->distvname . "\n";

=head2 filename

The filename method returns the filename of the release:

  print " Filename: " . $acme_colours[0]->filename . "\n";

=head2 maturity

The maturity method returns the maturity of the release:

  print " Maturity: " . $acme_colours[0]->maturity . "\n";

=head2 prefix

The prefix method returns the prefix of the release:

  print "   Prefix: " . $acme_colours[0]->prefix . "\n";

=head2 version

The version method returns the version of the release:

  print "  Version: " . $acme_colours[0]->version . "\n";

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2005, Leon Brocard

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Parse::BACKPAN::Packages>

