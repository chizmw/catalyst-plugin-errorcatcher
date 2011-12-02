package Catalyst::Plugin::ErrorCatcher::Plugin::CleanUp::TxnDo;
use strict;
use warnings;

sub tidy_message {
    my $plugin      = shift;
    my $errstr_ref  = shift;

    # DBIx::Class::Schema::txn_do(): ... ... line XX
    ${$errstr_ref} =~ s{
        DBIx::Class::Schema::txn_do\(\):
        \s+
        (.+?)
        \s+at\s+
        \S+
        \s+
        line
        \s+
        .*
        $
    }{$1}xmsg;

    $errstr_ref;
}

1;
# ABSTRACT: cleanup txn_do messages from Pg
