# Load the Module::Install bundled in ./inc/
use inc::Module::Install '0.87';

# Define metadata
name            'Catalyst-Plugin-ErrorCatcher';
version         '0.0.6.4';
all_from        'lib/Catalyst/Plugin/ErrorCatcher.pm';

# Specific dependencies
build_requires(
    'Test::More'                        => '0.92',  # core since 5.006002
    'Test::Simple'                      => '0.88',
    'Catalyst::Plugin::Authentication'  => 0,
    'Catalyst::Plugin::ConfigLoader'    => 0,
    'Catalyst::Plugin::StackTrace'      => 0,
    'Catalyst::Runtime'                 => '5.71001',
    'Catalyst::Test'                    => 0,
    'Config::General'                   => 0,
    'DateTime'                          => '0.42',
    'File::Find::Rule'                  => '0.30',
    'File::Path'                        => 0,
    'File::Slurp'                       => '9999.12',
    'FindBin'                           => 0,   # core since 5.00307
    'MIME::Lite'                        => '3.023',
    'Path::Class'                       => '0.16',
    'Sys::Hostname'                     => 0,   # core since perl 5
);

requires(
    'Catalyst::Runtime'                 => '5.71001',
    'Class::Data::Accessor'             => 0,
    'IO::File'                          => 0,   # core since 5.00307
    'MRO::Compat'                       => 0,
    'version'                           => 0,   # core since 5.009
);

recommends(
    'DateTime'                          => '0.42',
    'File::Slurp'                       => '9999.12',
    'MIME::Lite'                        => '3.023',
    'Path::Class'                       => '0.16',
);

auto_install;
WriteAll;
