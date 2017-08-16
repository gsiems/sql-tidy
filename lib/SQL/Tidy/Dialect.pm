package SQL::Tidy::Dialect;
use strict;
use warnings;

use Carp();

=head1 NAME

SQL::Tidy::Dialect

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over

=cut

=item new

Create, and return, a new instance of this

=cut

sub new {
    my ( $this, $args ) = @_;

    my $dialect = $args->{dialect} || 'Default';

    my $driver_class = "SQL::Tidy::Dialect::$dialect";
    eval qq{package                     # hide from PAUSE
        SQL::Tidy::_firesafe;           # just in case
        require $driver_class;          # load the driver
    };

    if ($@) {
        my $err = $@;
        Carp::croak("install_driver($driver_class) failed: $err\n");
    }

    my $self = $driver_class->new($args);

    return $self;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
