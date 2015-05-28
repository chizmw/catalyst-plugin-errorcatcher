package Catalyst::Plugin::ErrorCatcher::Plugin::CleanUp::Pg::MissingColumn;
use strict;
use warnings;

=head2 tidy_message($self, $stringref)

Tidy up Postgres messages where the error is related to a I<DBI exception>.

=cut
sub tidy_message {
    my $plugin      = shift;
    my $errstr_ref  = shift;

    # column XXX does not exist
    ${$errstr_ref} =~ s{
        \A
        .+?
        DBI \s Exception:
        .+?
        ERROR:\s+
        (column \s+ \S+ \s+ does \s+ not \s+ exist)
        \s+
        .+
        $
    }{$1}xmsg;

    $errstr_ref;
}

1;
# ABSTRACT: cleanup column XXX does not exist messages from Pg
