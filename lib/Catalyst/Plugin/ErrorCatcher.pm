package Catalyst::Plugin::ErrorCatcher;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use 5.008001;
use base qw/Class::Data::Accessor/;
use IO::File;
use MRO::Compat;

use version; our $VERSION = qv(0.0.6.4)->numify;

__PACKAGE__->mk_classaccessor(qw/_errorcatcher/);
__PACKAGE__->mk_classaccessor(qw/_errorcatcher_msg/);
__PACKAGE__->mk_classaccessor(qw/_errorcatcher_cfg/);
__PACKAGE__->mk_classaccessor(qw/_errorcatcher_c_cfg/);
__PACKAGE__->mk_classaccessor(qw/_errorcatcher_first_frame/);

sub setup {
    my $c = shift @_;

    # make sure other modules (e.g. ConfigLoader) work their magic
    $c->maybe::next::method(@_);

    # store the whole config (so plugins have a method to access it)
    $c->_errorcatcher_c_cfg( $c->config );

    # get our plugin config
    my $config = $c->config->{'Plugin::ErrorCatcher'} || {};

    # set some defaults
    $config->{context}      ||= 4;
    $config->{verbose}      ||= 0;
    $config->{always_log}   ||= 0;

    # store our plugin config
    $c->_errorcatcher_cfg( $config );
}

# implementation borrowed from ABERLIN
sub finalize_error {
    my $c = shift;
    my $conf = $c->_errorcatcher_cfg;

    # finalize_error is only called when we have $c->error, so no need to test
    # for it

    # this should let ::StackTrace do some of our heavy-lifting
    # and prepare the Devel::StackTrace frames for us to re-use
    $c->maybe::next::method(@_);

    # don't run if user is certain we shouldn't
    if (
        # the config file insists we DO NOT run
        defined $conf->{enable} && not $conf->{enable}
    ) {
        return;
    }

    # run if required
    if (
        # the config file insists we run
        defined $conf->{enable} && $conf->{enable}
            or
        # we're in debug mode
        !defined $conf->{enable} && $c->debug
    ) {
        $c->my_finalize_error;
    }

    return;
}

sub my_finalize_error {
    my $c = shift;
    $c->_keep_frames;
    $c->_prepare_message;
    $c->_emit_message;
    return;
}

sub _emit_message {
    my $c = shift;
    my $conf = $c->_errorcatcher_cfg;
    my $emitted_count = 0;

    return
        unless defined($c->_errorcatcher_msg);

    # use a custom emit method?
    if (defined (my $emit_list = $c->_errorcatcher_cfg->{emit_module})) {
        my @emit_list;
        # one item or a list?
        if (defined ref($emit_list) and 'ARRAY' eq ref($emit_list)) {
            @emit_list = @{ $emit_list };
        }
        elsif (not ref($emit_list)) {
            @emit_list = ( $emit_list );
        }

        foreach my $emitter (@emit_list) {
            $c->log->debug(
                  q{Trying to use custom emitter: }
                . $emitter
            ) if $conf->{verbose};

            # require, and call methods
            my $emitted_ok = $c->_require_and_emit(
                $emitter, $c->_errorcatcher_msg
            );
            if ($emitted_ok) {
                $emitted_count++;
                $c->log->debug(
                      $emitter
                    . q{: OK}
                ) if $conf->{verbose};
            }
            else {
                $c->log->debug(
                      $emitter
                    . q{: FAILED}
                ) if $conf->{verbose};
            }
        }
    }

    # by default use $c->log
    if (
        not $emitted_count
            or
        $c->_errorcatcher_cfg->{always_log}
    ) {
        $c->log->info(
            $c->_errorcatcher_msg
        );
    }

    return;
}

sub _require_and_emit {
    my $c = shift;
    my $emitter_name = shift;
    my $output = shift;
    my $conf = $c->_errorcatcher_cfg;

    # make sure our emitter loads
    eval "require $emitter_name";
    if ($@) {
        $c->log->error($@);
        return;
    }
    # make sure it "can" emit
    if ($emitter_name->can('emit')) {
        eval {
            $emitter_name->emit(
                $c, $output
            );
        };
        if ($@) {
            $c->log->error($@);
            return;
        }

        $c->log->debug(
                $emitter_name
            . q{: emitted without errors}
        ) if $conf->{verbose} > 1;

        # we are happy when they emitted without incident
        return 1;
    }
    else {
        $c->log->debug(
                $emitter_name
            . q{ does not have an emit() method}
        ) if $conf->{verbose};
    }

    # default is, "no we didn't emit anything"
    return;
}

sub _cleaned_error_message {
    my $error_message = shift;

    # Caught exception ... ... line XX."
    $error_message =~ s{
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

    # DBIx::Class::Schema::txn_do(): ... ... line XX
    $error_message =~ s{
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

    chomp $error_message;
    return $error_message;
}

sub _prepare_message {
    my $c = shift;
    my ($feedback, $full_error, $parsed_error);

    # get the (list of) error(s)
    for my $error (@{ $c->error }) {
        $full_error .= qq{$error\n\n};
    }
    # trim out some extra fluff from the full message
    $parsed_error = _cleaned_error_message($full_error);

    # A title for the feedback
    $feedback .= qq{Exception caught:\n};

    # the (parsed) error
    $feedback .= "\n   Error: " . $parsed_error . "\n";

    # general request information
    # some of these aren't always defined...
    $feedback .= "    Time: " . scalar(localtime) . "\n";

    $feedback .= "  Client: " . $c->request->address
        if (defined $c->request->address);
    if (defined $c->request->hostname) {
        $feedback .=        " (" . $c->request->hostname . ")\n"
    }
    else {
        $feedback .= "\n";
    }

    if (defined $c->request->user_agent) {
        $feedback .= "   Agent: " . $c->request->user_agent . "\n";
    }
    $feedback .= "     URI: " . ($c->request->uri||q{n/a}) . "\n";
    $feedback .= "  Method: " . ($c->request->method||q{n/a}) . "\n";

    # if we have a logged-in user, add to the feedback
    if (
           $c->user_exists
        && $c->user->can('id')
    ) {
        $feedback .= "    User: " . $c->user->id;
        if (ref $c->user) {
            $feedback .= " (" . ref($c->user) . ")\n";
        }
        else {
            $feedback .= "\n";
        }
    }

    if ('ARRAY' eq ref($c->_errorcatcher)) {
        # push on information and context
        for my $frame ( @{$c->_errorcatcher} ) {
            # clean up the common filename of
            # .../MyApp/script/../lib/...
            if ( $frame->{file} =~ /../ ) {
                $frame->{file} =~ s{script/../}{};
            }

            # if we haven't stored a frame, do so now
            # this is useful for easy access to the filename, line, etc
            if (not defined $c->_errorcatcher_first_frame) {
                $c->_errorcatcher_first_frame($frame);
            }

            my $pkg  = $frame->{pkg};
            my $line = $frame->{line};
            my $file = $frame->{file};
            my $code_preview = _print_context(
                $frame->{file},
                $frame->{line},
                $c->_errorcatcher_cfg->{context}
            );

            $feedback .= "\nPackage: $pkg\n   Line: $line\n   File: $file\n";
            $feedback .= "\n$code_preview\n";
        }
    }
    else {
        $feedback .= "\nStack trace unavailable - use and enable Catalyst::Plugin::StackTrace\n";
    }

    # in case we bugger up the s/// on the original error message
    if ($full_error) {
        $feedback .= "\nOriginal Error:\n\n$full_error";
    }

    # store it, otherwise we've done the above for mothing
    if (defined $feedback) {
        $c->_errorcatcher_msg($feedback);
    }

    return;
}

# we don't have to do much here now that we're relying on ::StackTrace to do
# the work for us
sub _keep_frames {
    my $c = shift;
    my $conf = $c->_errorcatcher_cfg;
    my $stacktrace;

    eval {
        $stacktrace = $c->_stacktrace;
    };

    if (defined $stacktrace) {
        $c->_errorcatcher( $stacktrace );
    }
    else {
        $c->log->debug(
                __PACKAGE__
            . q{ has no stack-trace information}
        ) if $conf->{verbose} > 1;
    }
    return;
}

# borrowed heavily from Catalyst::Plugin::StackTrace
sub _print_context {
    my ( $file, $linenum, $context ) = @_;

    my $code;
    if ( -f $file ) {
        my $start = $linenum - $context;
        my $end   = $linenum + $context;
        $start = $start < 1 ? 1 : $start;
        if ( my $fh = IO::File->new( $file, 'r' ) ) {
            my $cur_line = 0;
            while ( my $line = <$fh> ) {
                ++$cur_line;
                last if $cur_line > $end;
                next if $cur_line < $start;
                my @tag = $cur_line == $linenum ? ('-->', q{}) : (q{   }, q{});
                $code .= sprintf(
                    '%s%5d: %s%s',
                        $tag[0],
                        $cur_line,
                        $line ? $line : q{},
                        $tag[1],
                );
            }
        }
    }
    return $code;
}

1;
__END__

=pod

=head1 NAME

Catalyst::Plugin::ErrorCatcher - Catch application errors and emit them somewhere

=head1 SYNOPSIS

  use Catalyst qw/-Debug StackTrace ErrorCatcher/;

=head1 DESCRIPTION

This plugin allows you to do More Stuff with the information that would
normally only be seen on the Catalyst Error Screen courtesy of the
L<Catalyst::Plugin::StackTrace> plugin.

=head1 CONFIGURATION

The plugin is configured in a similar manner to other Catalyst plugins:

  <Plugin::ErrorCatcher>
    enable      1
    context     5
    always_log  0

    emit_module A::Module
  </Plugin::ErrorCatcher>

=over 4

=item B<enable>

Setting this to I<true> forces the module to work its voodoo.

It's also enabled if the value is unset and you're running Catalyst in
debug-mode.

=item B<context>

When there is stack-trace information to share, how many lines of context to
show around the line that caused the error.

=item B<emit_module>

This specifies which module to use for custom output behaviour.

You can chain multiple modules by specifying a line in the config for each
module you'd like used:

    emit_module A::Module
    emit_module Another::Module
    emit_module Yet::Another::Module

If none are specified, or all that are specified fail, the default behaviour
is to log the prepared message at the INFO level via C<$c-E<gt>log()>.

For details on how to implement a custom emitter see L</"CUSTOM EMIT CLASSES">
in this documentation.

=item B<always_log>

The default plugin behaviour when using one or more emitter modules is to
suppress the I<info> log message if one or more of them succeeded.

If you wish to log the information, via C<$c-E<gt>log()> then set this value
to 1.

=back

=head1 STACKTRACE IN REPORTS WHEN NOT RUNNING IN DEBUG MODE

It is possible to run your application in non-Debug mode, and still have
errors reported with a stack-trace.

Include the StackTrace and ErrorCatcher plugins in MyApp.pm:

  use Catalyst qw<
    ErrorCatcher
    StackTrace
  >;

Set up your C<myapp.conf> to include the following:

  <stacktrace>
    enable      1
  </stacktrace>

  <Plugin::ErrorCatcher>
    enable      1
    # include other options here
  <Plugin::ErrorCatcher>

Any exceptions should now show your user the I<"Please come back later">
screen whilst still capturing and emitting a report with stack-trace.

=head1 PROVIDED EMIT CLASSES

=head2 Catalyst::Plugin::ErrorCatcher::Email

This module uses L<MIME::Lite> to send the prepared output to a specified
email address.

See L<Catalyst::Plugin::ErrorCatcher::Email> for usage and configuration
details.

=head1 CUSTOM EMIT CLASSES

A custom emit class takes the following format:

  package A::Module;
  # vim: ts=8 sts=4 et sw=4 sr sta
  use strict;
  use warnings;
  
  sub emit {
    my ($class, $c, $output) = @_;
  
    $c->log->info(
      'IGNORING OUTPUT FROM Catalyst::Plugin::ErrorCatcher'
    );
  
    return;
  }
  
  1;
  __END__

The only requirement is that you have a sub called C<emit>.

C<Catalyst::Plugin::ErrorCatcher> passes the following parameters in the call
to C<emit()>:

=over 4

=item B<$class>

The package name

=item B<$c>

A L<Context|Catalyst::Manual::Intro/"Context"> object

=item B<$output>

The processed output from C<Catalyst::Plugin::ErrorCatcher>

=back

If you want to use the original error message you should use:

  my @error = @{ $c->error };

You may use and abuse any Catalyst methods, or other Perl modules as you see
fit.

=head1 KNOWN ISSUES

The test-suite coverage is quite low.

=head1 SEE ALSO

L<Catalyst>,
L<Catalyst::Plugin::StackTrace>

=head1 AUTHORS

Chisel Wright C<< <chisel@herlpacker.co.uk> >>

=head1 THANKS

The authors of L<Catalyst::Plugin::StackTrace>, from which a lot of
code was used.

Ash Berlin for guiding me in the right direction after a known hacky first
implementation.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
