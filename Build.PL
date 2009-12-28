use Module::Build;
use strict;

my $build = Module::Build->new(
  create_makefile_pl => 'traditional',
  license            => 'perl',
  module_name        => 'BackPAN::Index',

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

  resources             => {
      bugtracker        => 'http://rt.cpan.org/Public/Dist/Display.html?Name=Parse-BACKPAN-Packages',
      repository        => 'http://github.com/acme/parse-backpan-packages',
  },

  recursive_test_files  => 1,
);
$build->create_build_script;
