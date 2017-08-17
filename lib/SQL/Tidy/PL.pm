package SQL::Tidy::PL;
use strict;
use warnings;

=head1 NAME

SQL::Tidy::PL

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

=item tag_pl ( tokens )

Replaces PL/SQL or PL/PgSQL or whatever procedural blocks
with a tag and stores the original PL in a reference hash.

Returns a hash-ref of the PL tags and the modified list of tokens.

=cut

sub tag_pl {
    my ( $self, @tokens ) = @_;

    my %pl;

    return ( \%pl, @tokens );

    my $pl_key;
    my @new_tokens;
    my $is_grant = 0;
    my $parens   = 0;

    foreach my $idx ( 0 .. $#tokens ) {

        my $token = $tokens[$idx];

=pod

Oracle:

CREATE [OR REPLACE] TRIGGER trigger_name

BEGIN

    ...

END [label] ;
/

------------------------------------------------------------------------

PostgreSQL

CREATE TRIGGER trigger_name

EXECUTE PROCEDURE ... ; -- No real PL; is contained in trigger function

------------------------------------------------------------------------

Oracle

CREATE OR REPLACE {FUNCTION|PROCEDURE} ... {IS|AS} -- beware of parens (may be an IS/AS inside signature?)

    ...

END [label] ;
/

------------------------------------

CREATE [OR REPLACE] PACKAGE ... AS
...

END [label] ;
/

------------------------------------

CREATE [OR REPLACE] PACKAGE BODY ... AS

END [label] ;
/

Note: Oracle functions/procedures can nest. '/' is for the entire block, not any sub-blocks

------------------------------------------------------------------------

PostgreSQL

CREATE FUNCTION ... AS <tag> ... <tag> [LANGUAGE lang] ;





=cut

    }

    return ( \%pl, grep { $_ ne '' } @new_tokens );
}

=item untag_pl ( PL, tokens )

Takes the hash of PL tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag_pl {
    my ( $self, $pls, @tokens ) = @_;
    return @tokens;

    my @new_tokens = ('');

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~pl_/ ) {
            push @new_tokens, @{ $pls->{$token} };
        }
        else {
            push @new_tokens, $token;
        }
    }

    return @new_tokens;
}

sub format_pl {
    my ( $self, $comments, $pls ) = @_;

    if ( $pls and ref($pls) eq 'HASH' ) {
        foreach my $key ( keys %{$pls} ) {
            my @ary = $self->add_vspace( $comments, @{ $pls->{$key} } );

            @ary = $self->add_indents(@ary);

            $pls->{$key} = \@ary;
        }
    }
    return $pls;
}

sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token       = uc $tokens[$idx];
        my $line_before = 0;
        my $line_after  = 0;

        if ( $token eq ';' ) {
            $line_after = 1;
        }
        elsif ( $token eq '/' ) {
            $line_after = 1;
        }
        elsif ( $token =~ m/^~~comment_/i ) {
            $line_before = $comments->{ lc $token }{newline_before};
            $line_after  = $comments->{ lc $token }{newline_after};
        }

        if ( 0 == $idx ) {
            $line_before = 0;
        }
        if ( $#tokens == $idx ) {
            $line_after = 0;
        }

        # Leading new-line
        if ( $line_before and $new_tokens[-1] ne "\n" ) {
            push @new_tokens, "\n";
        }

        push @new_tokens, $tokens[$idx];

        # Trailing new-line
        if ($line_after) {
            push @new_tokens, "\n";
        }
    }

    return @new_tokens;
}

sub add_indents {
    my ( $self, @tokens ) = @_;
    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = uc $tokens[$idx];

        push @new_tokens, $tokens[$idx];

    }

    return @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
