#!perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/lib";
}

use Test::More;

BEGIN {
    $ENV{ TESTAPP_CONFIG } = "$FindBin::Bin/lib/testapp.conf";
}

plan tests => 9;
use Catalyst::Test 'TestApp';

{
    eval "require Catalyst::Plugin::ErrorCatcher::Email";
    is( $@, q{}, "no require errors" );

    # make a request
    ok( my ($res,$c) = ctx_request('http://localhost/foo/ok'), 'request ok' );
    # check the config
    is_deeply(
        $c->_errorcatcher_c_cfg->{'Plugin::ErrorCatcher::Email'},
        {
            to => 'address@example.com',
            from => 'another@example.com',
            subject => 'Alternative Subject Line',
        },
        'email emitter config ok',
    );

    my $config = Catalyst::Plugin::ErrorCatcher::Email::_check_config(
        $c, q{Dummy Output},
    );
    is( ref($config), q{HASH}, q{returned config is a hashref} );

    # check the prepared config
    is_deeply(
        $config,
        {
            to => 'address@example.com',
            from => 'another@example.com',
            subject => 'Alternative Subject Line',
        },
        'email emitter config ok',
    );
}

{
    eval "require Catalyst::Plugin::ErrorCatcher::Email";
    is( $@, q{}, "no require errors" );

    # make a request
    ok( my ($res,$c) = ctx_request('http://localhost/foo/ok'), 'request ok' );
    # munge the config
    $c->_errorcatcher_c_cfg->{'Plugin::ErrorCatcher::Email'} =
    {
        to => 'address@example.com',
    };

    my $config = Catalyst::Plugin::ErrorCatcher::Email::_check_config(
        $c, q{Dummy Output},
    );
    is( ref($config), q{HASH}, q{returned config is a hashref} );

    # check the prepared config
    is_deeply(
        $config,
        {
            to => 'address@example.com',
            from => 'address@example.com',
            subject => 'Error Report for TestApp on localhost',
        },
        'munged email emitter config ok',
    );
}
