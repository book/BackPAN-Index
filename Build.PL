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
    'LWP::Simple'           => '0',
    'Archive::Extract'      => '0',
    'DBIx::Class'           => '0.08109',
    'DBD::SQLite'           => '1.25',
    'DBIx::Class::Schema::Loader'       => '0.04005',
    'Path::Class'           => '0.17',
    autodie                 => '0',
    parent                  => '0',
  },
  build_requires     => {
    'Test::More'            => '0',
    'Test::Compile'         => '0.11',
  },
);
$build->create_build_script;
