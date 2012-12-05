package Catalyst::Plugin::ErrorCatcher::Plugin::CleanUp::Pg::UniqueConstraintViolation;
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
        duplicate \s+ key \s+ value \s+
        violates \s unique \s constraint \s
        "(.+?)" \s
        .+?
        Key \s+ \(
            (.+?)
        \)
        \= \(
            (.+?)
        \)
        \s+ already \s+ exists
        .+
        $
    }{Unique constraint violation: $2 -> $3 [$1]}xmsg;

    $errstr_ref;
}

1;

# ABSTRACT: cleanup foreign key violation messages from Pg

