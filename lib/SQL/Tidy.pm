package SQL::Tidy;
use strict;
use warnings;

use Carp();
use Data::Dumper;

use SQL::Tidy::Comment;
use SQL::Tidy::Dialect;
use SQL::Tidy::DDL;
use SQL::Tidy::DML;
use SQL::Tidy::PL;
use SQL::Tidy::String;
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
    $args->{use_tabs}       ||= 0;            # Spaces all the way
    $args->{tab_size}       ||= 4;
    $args->{max_line_width} ||= 120;
    $args->{min_line_width} ||= 40;
    $args->{case_folding}   ||= 'upper';      # It is in the SQL standard after all
    $args->{dialect}        ||= 'Default';    # Oracle, PostgreSQL, ...

    if ( not defined $args->{uppercase_keywords} ) {
        $args->{uppercase_keywords} = 1;
    }

    # Convert Oracle functions:
    $args->{convert_nvl}    ||= 0;            # Convert nvl to coalesce
    $args->{convert_nvl2}   ||= 0;            # Convert nvl2 to CASE structure
    $args->{convert_decode} ||= 0;            # Convert decode to CASE structure

    # Regexp for "Safe-to-unquote" identifiers
    # Not that this will probably ever make sense as a config option...
    $args->{stu_ident} ||= '[A-Z0-9_]+';
    my $stu_ident = $args->{stu_ident};
    $args->{stu_re} = qr/^"$stu_ident"$/;

    foreach my $key ( keys %{$args} ) {
        unless ( exists $args->{$key} ) {
            $self->{$_} = $args->{$_};
        }
    }

    $args->{space_re} = qr/^[ \t]+$/;

    $self->{tokenizer} = SQL::Tidy::Tokenize->new($args);
    $self->{comments}  = SQL::Tidy::Comment->new($args);
    $self->{strings}   = SQL::Tidy::String->new($args);
    $self->{dialect}   = SQL::Tidy::Dialect->new($args);
    $self->{ddl}       = SQL::Tidy::DDL->new($args);
    $self->{dmls}      = SQL::Tidy::DML->new($args);
    $self->{pls}       = SQL::Tidy::PL->new($args);

    return $self;
}

=item tidy ( code )

Takes a string of code, formats it, and returns the result

=cut

sub tidy {
    my ( $self, $code ) = @_;

    my $comments;
    my $strings;
    my $dml;
    my $pl;
    my @tokens = $self->{tokenizer}->tokenize_sql($code);

    ( $comments, @tokens ) = $self->{comments}->tag_comments(@tokens);
    ( $strings,  @tokens ) = $self->{strings}->tag_strings(@tokens);

    @tokens = $self->normalize(@tokens);
    ( $dml, @tokens ) = $self->{dmls}->tag_dml(@tokens);

    # TODO: format pieces (to include unquoting identifiers/capitalizing key-words)

    ( $pl, @tokens ) = $self->{pls}->tag_pl(@tokens);

    @tokens = $self->{ddl}->format_ddl( $comments, @tokens );

    $pl = $self->{pls}->format_pl( $comments, $pl );

    $dml = $self->{dmls}->format_dml( $comments, $dml );

    @tokens = $self->{pls}->untag_pl( $pl, @tokens );
    @tokens = $self->{dmls}->untag_dml( $dml, @tokens );

    # TODO: Fix line-wrapping here? Or as part of format DDL/DML/PL?
    @tokens = $self->fix_spacing(@tokens);

    @tokens = $self->{strings}->untag_strings( $strings, @tokens );
    @tokens = $self->{comments}->untag_comments( $comments, @tokens );

    # TODO: any cleanup?

    $code = join( '', @tokens );

    $code =~ s/^\n+//;
    $code =~ s/RETURN - /RETURN -/g;
    $code =~ s/\( \)/()/g;
    $code =~ s/\( \* \)/(*)/g;

    return $code;
}

=item normalize ( tokens )

Remove white-space and empty tokens from the supplied list of tokens

Returns the modified list

=cut

sub normalize {
    my ( $self, @tokens ) = @_;
    my @new_tokens;

    foreach my $token (@tokens) {

        if ( $token eq '' ) {
            # Remove empty tokens
        }
        elsif ( $token eq "\n" or $token eq "\r" ) {
            # Remove new-lines
        }
        elsif ( $token =~ m/^[ \t]+$/ ) {
            # Remove spaces
        }
        else {
            push @new_tokens, $token;
        }
    }

    return @new_tokens;
}

sub fix_spacing {
    my ( $self, @tokens ) = @_;

    # In general we assume a space between all tokens and only worry
    # about the cases where that is not the case.
    my @new_tokens = map { $_, ' ' } @tokens;
    unshift @new_tokens, '';
    push @new_tokens, '';

    foreach my $idx ( 1 .. $#new_tokens - 1 ) {
        my $token = $new_tokens[$idx];

        # No spaces before or after new lines
        if ( $token eq "\n" ) {
            $new_tokens[ $idx - 1 ] = '';
            $new_tokens[ $idx + 1 ] = '';
        }
        # No spaces before commas
        elsif ( $token eq ',' ) {
            $new_tokens[ $idx - 1 ] = '';
        }

        # No spaces on either side of existing multiple-spaces
        elsif ( $token =~ m/^  +$/ ) {
            $new_tokens[ $idx - 1 ] = '';
            $new_tokens[ $idx + 1 ] = '';
        }
        # Comparisons
        # if it is a math operator combined with a number and comparison operator then what?
        # '= +1', '> -1'.
        # '-3 >=' ???
        elsif ( $token =~ m/^[-+]$/
            and exists $self->{operators}{ $new_tokens[ $idx - 2 ] }{comparison}
            and $new_tokens[ $idx + 2 ] =~ m/^[0-9.]/ )
        {

            $new_tokens[ $idx + 1 ] = '';
        }
    }

    # remove trailing spaces from the end of the token list
    my $re_spaces = qr/^ +$/;

    foreach my $idx ( 1 .. $#new_tokens ) {
        my $token = $new_tokens[ -$idx ];
        next if ( $token eq '' );
        if ( $token =~ $re_spaces ) {
            $new_tokens[ -$idx ] = '';
        }
        else {
            last;
        }
    }

    return grep { $_ ne '' } @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
