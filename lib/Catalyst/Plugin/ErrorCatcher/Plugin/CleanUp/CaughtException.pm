package Catalyst::Plugin::ErrorCatcher::Plugin::CleanUp::CaughtException;

use strict;
use warnings;

=head2 tidy_message($self, $stringref)

Tidy up Postgres messages where the error is related to a I<Caught exception>.

=cut
sub tidy_message {
    my $plugin      = shift;
    my $errstr_ref  = shift;

    ${$errstr_ref} =~ s{
        Caught\s+exception\s+in\s+
        \S+\s+
        "
        (.+?)
        \s+at\s+
        \S+
        \s+
        line
        \s+
        .*
        "
        $
    }{$1}xmsg;

    $errstr_ref;
}

1;
# ABSTRACT: cleanup caught exception messages from Pg
