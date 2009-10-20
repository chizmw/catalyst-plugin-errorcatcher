package Catalyst::Plugin::ErrorCatcher::Email;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use version; our $VERSION = qv(0.0.2.3)->numify;

use MIME::Lite;
use Sys::Hostname;

sub emit {
    my ($class, $c, $output) = @_;
    my ($config, $msg);

    # check and tidy the config
    $config = _check_config($c, $config);

    # build the message
    my %msg_config = (
        From    => $config->{from},
        To      => $config->{to},
        Subject => $config->{subject},

        Type    => 'TEXT',
        Data    => $output,
    );
    # add the optional Cc value
    if (exists $config->{cc}) {
        $msg_config{Cc} = $config->{cc};
    }
    $msg = MIME::Lite->new( %msg_config );

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

    # allow people to put Magic Tags into the subject line
    # (nifty idea suggested by pecastro)
    # only use them if we have a user subject *AND* they've asked us to work
    # the magic on it
    if (
           defined $config->{subject}
        && $config->{use_tags}
    ) {
        $config->{subject} =
            _parse_tags($c, $config->{subject});
    }

    # set a default Subject-Line
    if (not defined $config->{subject}) {
        $config->{subject} =
              q{Error Report for }
            . $c->config->{name}
        ;
        my $host = Sys::Hostname::hostname();
        if (defined $host) {
            $config->{subject} .=
                  q{ on }
                . $host
            ;
        }
    }

    return $config;
}

# supported tags
#  %h   server hostname
#  %f   filename where error occurred
#  %F   filename where error occurred, leading directories trimmed
#  %l   line number where error occurred
#  %p   package where error occurred
#  %V   application version (if set)
sub _parse_tags {
    my $c       = shift;
    my $subject = shift;

    my %tag_of = (
        '%h' => sub{Sys::Hostname::hostname()||'UnknownHost'},
        '%f' => sub{$c->_errorcatcher_first_frame->{file}||'UnknownFile'},
        '%F' => sub{
            my $val=$c->_errorcatcher_first_frame->{file}||'UnknownFile';
            # ideally replace with cross-platform directory separator
            $val =~ s{\A.+/(?:lib|script)/}{};
            return $val;
        },
        '%l' => sub{$c->_errorcatcher_first_frame->{line}||'UnknownLine'},
        '%p' => sub{$c->_errorcatcher_first_frame->{pkg}||'UnknownPackage'},
        '%V' => sub{$c->config->{version}||'UnknownVersion'},
        '%n' => sub{$c->config->{name}||'UnknownAppName'},
    );

    foreach my $tag (keys %tag_of) {
        $subject =~ s{$tag}{&{$tag_of{$tag}}}eg;
    }

    return $subject;
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

SUBJECT LINE TAGS

There are some tags which can be used in the subject line which will be
replaced with appropriate values. You need to enable tag parsing in your
configuration:

  <Plugin::ErrorCatcher::Email>
   # ...
   use_tags 1
  </Plugin::ErrorCatcher::Email>

Available tags are:

  %f   filename where error occurred
  %F   filename where error occurred, leading directories trimmed
  %h   server hostname
  %l   line number where error occurred
  %N   application name
  %p   package where error occurred
  %V   application version

Allowing you to set your subject like this:

  <Plugin::ErrorCatcher::Email>
   # ...

   subject    Report from: %h; %F, line %l
  </Plugin::ErrorCatcher::Email>

=head1 AUTHORS

Chisel Wright C<< <chisel@herlpacker.co.uk> >>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
