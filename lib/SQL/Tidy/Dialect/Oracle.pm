package SQL::Tidy::Dialect::Oracle;
use base 'SQL::Tidy::Dialect';

use strict;
use warnings;

=head1 NAME

SQL::Tidy::Dialect::Oracle

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
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    foreach my $key ( keys %{$args} ) {
        unless ( exists $args->{$key} ) {
            $self->{$_} = $args->{$_};
        }
    }

    return $self;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
