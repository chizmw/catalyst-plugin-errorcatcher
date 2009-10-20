package Catalyst::Plugin::ErrorCatcher::File;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use version; our $VERSION = qv(0.0.1.1)->numify;

use DateTime;
use Path::Class;
use File::Slurp qw(write_file);

sub emit {
    my ($class, $c, $output) = @_;
    my ($config);

    # check and tidy the config
    $config = _check_config($c, $config);

    # write the error out as a file on disk
    _write_file($output, $config);

    return;
}

sub _check_config {
    my $c = shift;

    my $config = $c->_errorcatcher_c_cfg->{"Plugin::ErrorCatcher::File"};

    # no config, no email
    # we die so we count as a failure
    if (not defined $config) {
        die "Catalyst::Plugin::ErrorCatcher::File has no configuration\n";
    }

    # no To:, no email
    if (not defined $config->{dir}) {
        die qq{Catalyst::Plugin::ErrorCatcher::File has no "dir" setting\n};
    }

    if (not defined $config->{prefix}) {
        $config->{prefix} = q{ecfile};
    }

    return $config;
}

sub _write_file {
    my $msg = shift;
    my $config = shift;

    my $dt = DateTime->now;
    my $timestamp = $dt->strftime('%Y%m%d%H%M%S');

    my $filename = file(
        $config->{dir},
          $config->{prefix}
        . q{_}
        . $timestamp
    );

    # make sure we don't overwrite existing files
    if (-e $filename) {
        my $count = 1;
        while (-e "${filename}.${count}") {
            $count++;
        }
        $filename = "${filename}.${count}";
    }

    write_file($filename.q{}, $msg);
    return;
}

1;
__END__

=pod

=head1 NAME

Catalyst::Plugin::ErrorCatcher::File - a file emitter for Catalyst::Plugin::ErrorCatcher

=head1 SYNOPSIS

In your application:

  use Catalyst qw/-Debug StackTrace ErrorCatcher/;

In your application configuration:

  <Plugin::ErrorCatcher>
    # ...

    emit_module Catalyst::Plugin::ErrorCatcher::File
  </Plugin::ErrorCatcher>

  <Plugin::ErrorCatcher::File>
    dir         /tmp

    # defaults to ecfile
    prefix      foobar

  </Plugin::ErrorCatcher::File>

=head1 AUTHORS

Chisel Wright C<< <chisel@herlpacker.co.uk> >>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
