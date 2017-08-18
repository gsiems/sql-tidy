package SQL::Tidy::Tokenize;
use strict;
use warnings;

use SQL::Tokenizer;

=head1 NAME

SQL::Tidy::Tokenize

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

=item tokenize_sql ( statement )

Takes a statement and tokenizes it using SQL::Tokenizer

Returns the list of tokens

=cut

sub tokenize_sql {
    my ( $self, $statement ) = @_;

    # TODO: carp or croak if no statement?
    return () unless ($statement);

    my @tokens = SQL::Tokenizer->tokenize( $statement, 0 );
    my @new_tokens;

    foreach my $token (@tokens) {

        # There is an issue with the tokenizer that chunks '#' with
        # extra characters as if it were a comment or something.
        # Nota bene: This may actually be valid for some SQL dialects;
        #   but it isn't valid for Postgres or Oracle.
        if ( $token =~ m/^\#/ ) {
            my @ary = split /(\#)/, $token;
            foreach my $t (@ary) {
                if ( $t eq '#' ) {
                    push @new_tokens, $t;
                }
                else {
                    my @ts = SQL::Tokenizer->tokenize( $t, 0 );
                    push @new_tokens, @ts;
                }
            }
        }
        else {
            push @new_tokens, $token;
        }
    }

    foreach my $idx ( 1 .. $#new_tokens ) {
        # Also, the tokenizer splits two character operators such that,
        # for example, '>=' is two tokens ('>' and '=') instead of the
        # desired one.
        if ( $new_tokens[$idx] =~ m/^[><=]$/ and $new_tokens[ $idx - 1 ] =~ m/^[><=!]$/ ) {
            $new_tokens[ $idx - 1 ] .= $new_tokens[$idx];
            $new_tokens[$idx] = undef;
        }
        # Likewise ':='
        elsif ( $new_tokens[$idx] eq '=' and $new_tokens[ $idx - 1 ] eq ':' ) {
            $new_tokens[ $idx - 1 ] .= $new_tokens[$idx];
            $new_tokens[$idx] = undef;
        }
    }

    return grep { defined $_ } @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
