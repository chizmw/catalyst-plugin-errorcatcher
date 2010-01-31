package NoAuth;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Catalyst;

our $VERSION = '0.0.2';

# hide debug output at startup
{
    no strict 'refs';
    no warnings;
    *{"Catalyst\::Log\::debug"} = sub { };
    *{"Catalyst\::Log\::info"}  = sub { };
}

NoAuth->config(
    name => 'NoAuth',
);

VERSION_MADNESS: {
    use version;
    my $vstring = version->new($VERSION)->normal;
    __PACKAGE__->config(
        version => $vstring
    );
}

NoAuth->setup(
    qw<
        -Debug
        StackTrace
        ErrorCatcher
        ConfigLoader
    >
);

1;
__END__
