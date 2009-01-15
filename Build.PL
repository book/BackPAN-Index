use Module::Build;
use strict;

my $build = Module::Build->new(
  create_makefile_pl => 'traditional',
  license            => 'perl',
  module_name        => 'Parse::BACKPAN::Packages',
  requires           => {
    'App::Cache'            => '0',
    'CPAN::DistnameInfo'    => '0',
    'Class::Accessor::Fast' => '0',
    'Compress::Zlib'        => '0',
    'IO::Zlib'              => '0',
    'LWP::UserAgent'        => '0',
    'Test::More'            => '0',
  },
);
$build->create_build_script;
