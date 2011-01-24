#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Catalyst::Plugin::ErrorCatcher;

my @test_cases = (
    {
        original    => q{Caught exception in SomeApp::Controller::Root->error500 "Can't locate object method "foo_forward" via package "SomeApp" at /home/person/development/someapp/script/../lib/SomeApp/Controller/Root.pm line 87."},
        cleaned     => q{Can't locate object method "foo_forward" via package "SomeApp"},
    },
    {
        original    => q{Error: DBIx::Class::ResultSetColumn::all(): DBI Exception: DBD::Pg::st execute failed: ERROR:  column me.name does not exist at character 8 [for Statement "SELECT me.name FROM product.product_channel me JOIN public.channel channel ON channel.id = me.channel_id WHERE ( ( me.product_id = ? AND me.creation_status_id = ? ) )" with ParamValues: 1='76660', 2='17'] at /opt/someapp/script/lib/SomeModule line 40},
        cleaned     => q{column me.name does not exist},
    },
    {
        original    => q{DBIx::Class::Schema::txn_do(): txn death at /home/chisel/development/github/TxnDo/script/../lib/TxnDo/Controller/Root.pm line 41.},
        cleaned     => q{txn death},
    },
);

foreach my $test (@test_cases) {
    is(
        Catalyst::Plugin::ErrorCatcher::_cleaned_error_message($test->{original}),
        $test->{cleaned},
        'cleaned to: ' . $test->{cleaned},
    );
}

done_testing;
