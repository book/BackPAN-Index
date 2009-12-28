use Module::Build;
use strict;

my $build = Module::Build->new(
  license            => 'perl',
  module_name        => 'BackPAN::Index',
  dist_author        => [
      'Leon Brocard <acme@astray.com>',
      'Michael G Schwern <schwern@pobox.com>',
  ],

  requires           => {
    'App::Cache'            => '0',
    'CPAN::DistnameInfo'    => '0.09',
    'Class::Accessor::Fast' => '0',
    CLASS                   => '1.00',
    'LWP::Simple'           => '0',
    'Archive::Extract'      => '0',
    'DBIx::Class'           => '0.08109',
    'DBD::SQLite'           => '1.25',
    'DBIx::Class::Schema::Loader'       => '0.04005',
    'Path::Class'           => '0.17',
    autodie                 => '0',
    parent                  => '0',
    perl                    => '5.008001',
  },

  build_requires     => {
    'Test::More'            => '0.90',
    'Test::Compile'         => '0.11',
  },

  recursive_test_files  => 1,

  meta_merge => {
      resources             => {
          bugtracker        => 'http://rt.cpan.org/Public/Dist/Display.html?Name=Parse-BACKPAN-Packages',
          repository        => 'http://github.com/acme/parse-backpan-packages',
      },
  },

  create_license        => 1,
  create_makefile_pl    => 'traditional',
  create_readme         => 1,
);
$build->create_build_script;
