package Catalyst::Plugin::ErrorCatcher::Plugin::CleanUp::Pg::ForeignKeyConstraint;
use strict;
use warnings;

sub tidy_message {
    my $plugin     = shift;
    my $errstr_ref = shift;

    # update or delete on table "foo" violates foreign key constraint
    # "foobar_fkey" on table "baz"
    ${$errstr_ref} =~ s{
        \A
        .+?
        DBI \s Exception:
        .+?
        ERROR:\s+
        update \s or \s delete \s on \s table \s
        "(.+?)" \s
        violates \s foreign \s key \s constraint \s
        "(.+?)" \s
        on \s table \s
        "(.+?)"
        \s+
        .+
        $
    }{Foreign key constraint violation: $1 -> $3 [$2]}xmsg;

    $errstr_ref;
}

1;

# ABSTRACT: cleanup foreign key violation messages from Pg
