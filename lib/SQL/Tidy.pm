package SQL::Tidy;
use strict;
use warnings;

use Carp();
use Data::Dumper;

use SQL::Tidy::Tokenize;

=head1 NAME

SQL::Tidy

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

    # Set defaults if not otherwise set
    $args->{use_tabs}       ||= 0;          # Spaces all the way
    $args->{tab_size}       ||= 4;
    $args->{max_line_width} ||= 120;
    $args->{min_line_width} ||= 40;
    $args->{keywords_case}  ||= 'upper';
    $args->{case_folding}   ||= 'upper';    # It is in the SQL standard after all

    # Regexp for "Safe-to-unquote" identifiers
    # Not that this will probably ever make sense as a config option...
    $args->{stu_ident} ||= '[A-Z0-9_]+';
    my $stu_ident = $args->{stu_ident};
    $args->{stu_re} ||= qr/^"$stu_ident"$/;

    foreach my $key ( keys %{$args} ) {
        unless ( exists $args->{$key} ) {
            $self->{$_} = $args->{$_};
        }
    }

    $self->{tokenizer} = SQL::Tidy::Tokenize->new($args);

    return $self;
}

=item tidy ( code )

Takes a string of code, formats it, and returns the result

=cut

sub tidy {
    my ( $self, $code ) = @_;

    my @tokens = $self->{tokenizer}->tokenize_sql($code);

    # TODO: This is a stub...

    $code = join( ' ', @tokens );

    return $code;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
