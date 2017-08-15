package SQL::Tidy::Indent;
use strict;
use warnings;

=head1 NAME

SQL::Tidy::Indent

=head1 SYNOPSIS

Convert between indent counts (tab-stops) and indent strings (tabs or
spaces)

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

=item to_indent ( tab_count )

Convert an input number of tab-stops to the appropriate indentation (
tabs or spaces ).

=cut

sub to_indent {
    my ( $self, $tab_count ) = @_;

    my $return = '';

    if ( $self->{use_tabs} ) {
        $return = "\t" x $tab_count;
    }
    else {
        $return = ' ' x ( $self->{tab_size} * $tab_count );
    }
    return $return;
}

=item to_tab_stops ( string )

Convert an input string to the corresponding number of tab-stops.

=cut

sub to_tab_count {
    my ( $self, $string ) = @_;

    my $return = 0;

    if ( !$string ) {
        $return = 0;
    }
    elsif ( $string =~ m/^[ ]+$/ ) {
        # If the string is all spaces then divide the length by the
        # number of spaces per tab-stop
        $return = int( length($string) / $self->{tab_size} );
    }
    elsif ( $string =~ m/^[\t]+$/ ) {
        # If the string is all tabs then return the number of tabs
        $return = length($string);
    }
    elsif ( $string =~ m/^[\t ]+$/ ) {
        # If the string is a mix... then...

        # space, space, tab => tab? (spaces up to tab_size - 1)
        # space, space, space, space => tab (spaces equal to tab_size)
        # tab => tab

        my $count = 0;
        foreach my $token ( split '', $string ) {
            if ( $token eq "\t" ) {
                $count = 0;
                $return++;
            }
            elsif ( $token eq ' ' ) {
                $count++;
                if ( $count == $self->{tab_size} ) {
                    $count = 0;
                    $return++;
                }
            }
        }
    }
    else {
        # Something looks wrong... it maybe isn't worth failing over
        # but it's hard to say what the result should be... maybe
        # int ( length / tab_size )?
        $return = 0;
    }

    return $return;
}

=item subtract_indents ( string, tab_count )

Remove tab_count spaces from a string

=cut

sub subtract_indents {
    my ( $self, $string, $tab_count ) = @_;

    # If the string has leading spaces and use_tabs is false then just
    # remove the appropriate amount of leading space

    # If the string has leading tabs and use_tabs is true then just
    # remove the appropriate number of tabs.

    # Otherwise... it's a bit complicated?

    my ($indent) = $string =~ m/^([\t ]+)/;
    if ($indent) {

        my $x;
        my $count = 0;
        foreach my $token ( split '', $indent ) {
            if ( $token eq "\t" ) {
                $count = 0;
                $x++;
            }
            elsif ( $token eq ' ' ) {
                $count++;
                if ( $count == $self->{tab_size} ) {
                    $count = 0;
                    $x++;
                }
            }
            last if ( $x >= $tab_count );
        }
        $string = substr( $string, $x );
    }

    return $string;
}

=item add_indents ( string, tab_count )

Add tab_count spaces to a string

=cut

sub add_indents {
    my ( $self, $string, $tab_stops ) = @_;

    my $return = '';
    $string = '' unless ( defined $string );

    if ( defined $tab_stops and $tab_stops > 0 ) {
        $return = $self->to_indent($tab_stops) . $string;
    }
    else {
        $return = $string;
    }

    return $return;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;

