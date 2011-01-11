#!perl

use strict;
use warnings;

use FindBin::libs;
use Test::More;

#plan tests => 25;
use Catalyst::Test 'TestApp';

open STDERR, '>/dev/null';

# test that a normal action executes ok
{
    ok( my $res = request('http://localhost/foo/ok'), 'request ok' );
    is( $res->content, 'ok', 'response ok' );
}

# test that a crashed action prints the appropriate debug screen
{
    ok( my $res = request('http://localhost/foo/not_ok'), 'request ok' );
    like( $res->content, qr{Caught exception.+TestApp::Controller::Foo::three}, 'error ok' );
    like( $res->content, qr{Stack Trace}, 'trace ok' );
    like( $res->content, qr{<td>30</td>}, 'line number ok' );
    like( $res->content, qr{<strong class="line">   30:     three\(\);}, 'context ok' );
}

TestApp->config->{stacktrace}{enable} = 0;
{
    ok( my $res = request('http://localhost/foo/not_ok'), 'request ok' );
    like( $res->content, qr{Caught exception.+TestApp::Controller::Foo::three}, 'error ok' );
    unlike( $res->content, qr{Stack Trace}, 'trace disable' );
}

# check output with stacktrace
TestApp->config->{stacktrace}{enable} = 1;
TestApp->config->{"Plugin::ErrorCatcher"}{enable} = 1;
{
    ok( my ($res,$c) = ctx_request('http://localhost/foo/not_ok'), 'request ok' );
    my $ec_msg;
    eval{ $ec_msg = $c->_errorcatcher_msg };
    ok( defined $ec_msg, 'parsed error message ok' );

    # make sure the parsed error looks sane
    like(
        $ec_msg,
        qr{Error: Undefined subroutine &TestApp::Controller::Foo::three called},
        'parsed error content ok'
    );

    # the caller stacktrace frame
    like(
        $ec_msg,
        qr{Package: TestApp::Controller::Foo\n\s+Line:\s+18},
        'caller Package/Line ok'
    );
    like( $ec_msg, qr{-->\s+18:\s+\$c->forward\( 'crash' \);}, 'caller line number ok' );

    # the actual error stacktrace frame
    like(
        $ec_msg,
        qr{Package: TestApp::Controller::Foo\n\s+Line:\s+30},
        'error Package/Line ok'
    );
    like( $ec_msg, qr{-->\s+30:\s+three\(\);}, 'error line number ok' );
}

# check output with no stacktrace
TestApp->config->{stacktrace}{enable} = 0;
TestApp->config->{"Plugin::ErrorCatcher"}{enable} = 1;
{
    ok( my ($res,$c) = ctx_request('http://localhost/foo/not_ok'), 'request ok' );
    my $ec_msg;
    eval{ $ec_msg = $c->_errorcatcher_msg };
    ok( defined $ec_msg, 'parsed error message ok' );

    # make sure the parsed error looks sane
    like(
        $ec_msg,
        qr{Error: Undefined subroutine &TestApp::Controller::Foo::three called},
        'parsed error content ok'
    );

    # the caller stacktrace frame
    unlike(
        $ec_msg,
        qr{Package: TestApp::Controller::Foo\n\s+Line:\s+18},
        'caller Package/Line ok'
    );
    unlike( $ec_msg, qr{-->\s+18:\s+\$c->forward\( 'crash' \);}, 'caller line number ok' );

    # the actual error stacktrace frame
    unlike(
        $ec_msg,
        qr{Package: TestApp::Controller::Foo\n\s+Line:\s+30},
        'error Package/Line ok'
    );
    unlike( $ec_msg, qr{-->\s+30:\s+three\(\);}, 'error line number ok' );

    # we should have a note about lack of stacktrace
    like(
        $ec_msg,
        qr{Stack trace unavailable - use and enable Catalyst::Plugin::StackTrace},
        'stacktrace hint ok'
    );
}


# check output with stacktrace
TestApp->config->{stacktrace}{enable} = 1;
TestApp->config->{"Plugin::ErrorCatcher"}{enable} = 1;
{
    ok( my ($res,$c) = ctx_request('http://localhost/foo/crash_user'), 'request ok' );
    my $ec_msg;
    eval{ $ec_msg = $c->_errorcatcher_msg };
    ok( defined $ec_msg, 'parsed error message ok' );

    # we should have some user information
    like(
        $ec_msg,
        qr{User: buffy \(Catalyst::Authentication::User::Hash\)},
        'user details ok'
    );

    like(
        $ec_msg,
        qr{Error: Vampire\n},
        'Buffy staked the vampire'
    );
}

# RT-64492 - check no session data in default report
TestApp->config->{stacktrace}{enable} = 1;
TestApp->config->{"Plugin::ErrorCatcher"}{enable} = 1;
{
    ok( my ($res,$c) = ctx_request('http://localhost/foo/not_ok'), 'request ok' );
    my $ec_msg;
    eval{ $ec_msg = $c->_errorcatcher_msg };
    ok( defined $ec_msg, 'parsed error message ok' );
    foreach my $session_key (qw/__created __updated/) {
        unlike(
            $ec_msg,
            qr{__created},
            "no instances of '$session_key' in report"
        );
    }
}

done_testing;
