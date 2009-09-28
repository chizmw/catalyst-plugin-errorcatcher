package Catalyst::Plugin::ErrorCatcher::Email;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use version; our $VERSION = qv(0.0.2)->numify;

use MIME::Lite;

sub emit {
    my ($class, $c, $output) = @_;
    my ($config, $msg);

    # check and tidy the config
    $config = _check_config($c, $config);

    # build the message
    $msg = MIME::Lite->new(
        From    => $config->{from},
        To      => $config->{to},
        Subject => $config->{subject},

        Type    => 'TEXT',
        Data    => $output,
    );

    # send the message
    _send_email($msg, $config);

    return;
}

sub _check_config {
    my $c = shift;

    my $config = $c->_errorcatcher_c_cfg->{"Plugin::ErrorCatcher::Email"};

    # no config, no email
    # we die so we count as a failure
    if (not defined $config) {
        die "Catalyst::Plugin::ErrorCatcher::Email has no configuration\n";
    }

    # no To:, no email
    if (not defined $config->{to}) {
        die "Catalyst::Plugin::ErrorCatcher::Email has no To: address\n";
    }

    # set a default From address
    if (not defined $config->{from}) {
        $config->{from} = $config->{to};
    }

    # set a default Subject-Line
    if (not defined $config->{subject}) {
        $config->{subject} =
              q{Error Report for }
            . $c->config->{name}
        ;
        if (defined $c->request->hostname) {
            $config->{subject} .=
                  q{ on }
                . $c->request->hostname
            ;
        }
    }

    return $config;
}

sub _send_email {
    my $msg = shift;
    my $config = shift;

    # if there are specific send options, use them
    if (exists $config->{send}{type} and exists $config->{send}{args}) {
        $msg->send(
            $config->{send}{type},
            @{ $config->{send}{args} }
        );
        return;
    }

    # use default send method
    $msg->send;

    return;
}

1;
__END__

=pod

=head1 NAME

Catalyst::Plugin::ErrorCatcher::Email - an email emitter for Catalyst::Plugin::ErrorCatcher

=head1 SYNOPSIS

In your application:

  use Catalyst qw/-Debug StackTrace ErrorCatcher/;

In your application configuration:

  <Plugin::ErrorCatcher>
    # ...

    emit_module Catalyst::Plugin::ErrorCatcher::Email
  </Plugin::ErrorCatcher>

  <Plugin::ErrorCatcher::Email>
    to      address@example.com

    # defaults to the To: address
    from    another@example.com

    # defaults to "Error Report For <AppName>"
    subject Alternative Subject Line
  </Plugin::ErrorCatcher::Email>

=head1 AUTHORS

Chisel Wright C<< <chisel@herlpacker.co.uk> >>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
