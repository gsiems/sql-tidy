package SQL::Tidy::String;
use strict;
use warnings;

=head1 NAME

SQL::Tidy::String

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

=item tag_strings ( tokens )

Replaces string tokens with a tag and stores the original string in a reference hash

Returns a hash-ref of the string tags and the modified list of tokens

=cut

sub tag_strings {
    my ( $self, @tokens ) = @_;
    my %strings;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^(')/ ) {
            my $key = '~~string_' . sprintf( "%06d", $idx );
            $strings{$key} = $token;
            $tokens[$idx] = $key;
        }
    }
    return ( \%strings, @tokens );
}

=item untag_strings ( strings, tokens )

Takes the hash of string tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag_strings {
    my ( $self, $strings, @tokens ) = @_;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~string_/ ) {
            $tokens[$idx] = $strings->{$token};
        }
    }
    return @tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
