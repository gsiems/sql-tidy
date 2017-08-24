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

    return $self;
}

sub dialect {
    return 'Oracle';
}

sub safe_ident_re {
    return qr /[A-Za-z0-9_#\$]+/;
}

sub pct_attribs {

    my %h;

    foreach my $word (
        qw(

        BULK_ROWCOUNT
        ROWTYPE
        FOUND
        NOTFOUND
        TYPE
        ISOPEN
        ROWCOUNT
        BULK_EXCEPTIONS

        )
        )
    {
        $h{ uc $word } = $word;
    }

    return %h;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
