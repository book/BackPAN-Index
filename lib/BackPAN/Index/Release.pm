package BackPAN::Index::Release;

use strict;
use warnings;

use overload
  q[""]         => sub { $_[0]->distvname },
  fallback      => 1;

use BackPAN::Index::Role::AsHash;

sub data_methods {
    return qw(dist version cpanid date path maturity);
}

sub filename {
    my $self = shift;
    return $self->file->filename;
}

sub path {
    my $self = shift;
    return $self->file;
}

# Compatibility with PBP
sub prefix {
    my $self = shift;
    return $self->file;
}

1;

__END__

=head1 NAME

BackPAN::Index::Release - A single release of a distribution

=head1 SYNOPSIS

  my $b = BackPAN::Index->new();

  # Find version 1.2.3 of Acme-Colour
  my $release = $b->release("Acme-Colour", '1.2.3');

  print "   CPANID: " . $release->cpanid . "\n";
  print "     Date: " . $release->date . "\n";
  print "     Dist: " . $release->dist . "\n";
  print "Distvname: " . $release->distvname . "\n";
  print " Filename: " . $release->filename . "\n";
  print " Maturity: " . $release->maturity . "\n";
  print "     Path: " . $release->path . "\n";
  print "  Version: " . $release->version . "\n";

=head1 DESCRIPTION

BackPAN::Index::Release objects represent releases,
individual tarballs/zip files, of a distribution on BackPAN.

For example, Acme-Pony-1.2.3.tar.gz is a release of the Acme-Pony
distribution.

=head1 METHODS

=head2 cpanid

    my $cpanid = $release->cpanid;

Returns the PAUSE ID of the author of the release.

=head2 date

    my $date = $release->date;

Returns the date of the release, in UNIX epoch seconds.

=head2 dist

    my $dist_name = $release->dist;

Returns the name of the distribution this release belongs to.

=head2 distvname

    my $distvname = $release->distvname;

Returns the name of the distribution, hyphen, and version.

=head2 file

    my $file = $release->file;

Returns the BackPAN::Index::File representing this release.

=head2 filename

    my $filename = $release->filename;

Returns the filename of the release, just the file part.

=head2 maturity

    my $maturity = $release->maturity;

Returns the maturity of the release.

=head2 path

    my $path = $release->path;

Returns the full path on CPAN to the release.

=head2 version

    my $version = $release->version;

Returns the version of the release:

=head2 as_hash

    my $data = $release->as_hash;

Returns a hash ref containing the data inside C<$release>.


=head1 AUTHOR

Leon Brocard <acme@astray.com> and Michael G Schwern <schwern@pobox.com>

=head1 COPYRIGHT

Copyright (C) 2005-2009, Leon Brocard

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<BackPAN::Index>, L<BackPAN::Index::Dist>, L<BackPAN::Index::File>

