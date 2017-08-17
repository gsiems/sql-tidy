package SQL::Tidy::DDL;
use strict;
use warnings;

=head1 NAME

SQL::Tidy::DDL

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



sub format_ddl {
    my ( $self, $comments, @tokens ) = @_;
    my  @new_tokens = $self->add_vspace( $comments, @tokens );
    @new_tokens = $self->add_indents(@new_tokens);

    return @new_tokens;
}


sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token       = uc $tokens[$idx];
        my $line_before = 0;
        my $line_after  = 0;

        if ($token eq ';') {
            $line_after = 1;
        }
        elsif ($token eq '/') {
            $line_after = 1;
        }
        elsif ( $token =~ m/^~~comment_/i ) {
            $line_before = $comments->{ lc $token }{newline_before};
            $line_after  = $comments->{ lc $token }{newline_after};
        }

        if (0 == $idx) {
            $line_before = 0
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
        my $token       = uc $tokens[$idx];

        push @new_tokens, $tokens[$idx];

    }

    return @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
