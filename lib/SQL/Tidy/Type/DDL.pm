package SQL::Tidy::Type::DDL;
use base 'SQL::Tidy::Type';
use strict;
use warnings;

use SQL::Tidy::Dialect;
use SQL::Tidy::Indent;

=head1 NAME

SQL::Tidy::Type::DDL

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over

=cut

my $Dialect;
my $indenter;
my $space_re;
my $case_folding;

=item new

Create, and return, a new instance of this

=cut

sub new {
    my ( $this, $args ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    $Dialect      = SQL::Tidy::Dialect->new($args);
    $indenter     = SQL::Tidy::Indent->new($args);
    $space_re     = $args->{space_re};
    $case_folding = $args->{case_folding} || 'upper';

    return $self;
}

sub format_ddl {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens = @tokens;

    @new_tokens = $self->unquote_identifiers(@new_tokens);
    @new_tokens = $self->capitalize_keywords(@new_tokens);

    @new_tokens = $self->add_vspace( $comments, @new_tokens );
    @new_tokens = $self->add_indents(@new_tokens);

    return @new_tokens;
}

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;

    my %keywords    = $Dialect->ddl_keywords();
    my $stu_re      = $Dialect->safe_ident_re();
    my %pct_attribs = $Dialect->pct_attribs();

    return $self->_unquote_identifiers( \%keywords, \%pct_attribs, $stu_re, $case_folding, @tokens );
}

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    my %keywords = $Dialect->ddl_keywords();
    return $self->_capitalize_keywords( \%keywords, @tokens );
}

sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens;
    my $parens      = 0;
    my $in_proc_sig = 0;
    my $in_view_sig = 0;
    my $current     = '';

    my %h = (
        'CREATE'   => 2,
        'ALTER'    => 2,
        'DROP'     => 2,
        'COMMENT'  => 2,
        'SECURITY' => 1,
        'LANGUAGE' => 1,
    );

    foreach my $idx ( 0 .. $#tokens ) {
        my $token       = uc $tokens[$idx];
        my $line_before = 0;
        my $line_after  = 0;

        if ( not $current and exists $h{$token} ) {
            $current = $token;
        }

        # Force function/procedure signatures to line-wrap
        if ( $current eq 'CREATE' ) {
            if ( $token eq 'FUNCTION' or $token eq 'PROCEDURE' or $token eq 'TRIGGER' ) {
                $in_proc_sig = $token;
            }
            elsif ( $token eq 'VIEW' ) {
                $in_view_sig = 1;
            }
        }

        if ( exists $h{$token} ) {
            $line_before = $h{$token};
        }
        elsif ( $token eq '(' ) {
            $parens++;
            if ( $in_proc_sig and $parens == 1 ) {
                $line_after = 1;
            }
            elsif ( $in_view_sig and $parens == 1 ) {
                $line_after = 1;
            }
            elsif ( $current eq 'CREATE' and $parens == 1 ) {
                $line_after = 1;
            }
        }
        elsif ( $token eq ')' ) {
            $parens--;
            if ( $in_proc_sig and $parens == 0 ) {
                $line_after = 1;
            }
            elsif ( $in_view_sig and $parens == 0 ) {
                $line_after = 1;
            }
        }
        elsif ( $token eq ',' ) {
            if ( $in_proc_sig and $parens == 1 ) {
                $line_after = 1;
            }
            elsif ( $in_view_sig and $parens == 1 ) {
                $line_after = 1;
            }
            elsif ( $parens == 1 ) {
                $line_after = 1;
            }
        }

        elsif ( $token eq ';' ) {
            $current    = 0;
            $line_after = 1;
        }
        elsif ( $token eq '/' ) {
            $line_after = 1;
        }

        elsif ( $token eq 'AS' ) {
            if ( $in_proc_sig and $in_proc_sig ne 'TRIGGER' and $parens == 0 ) {
                $in_proc_sig = 0;
                $line_before = 1;
                $line_after  = 1;
            }
            elsif ( $in_view_sig and $parens == 0 ) {
                $in_view_sig = 0;
                $line_before = 1;
                $line_after  = 1;
            }
        }
        elsif ( $token eq 'IS' ) {
            if ( $in_proc_sig and $in_proc_sig ne 'TRIGGER' and $parens == 0 ) {
                $in_proc_sig = 0;
                $line_before = 1;
                $line_after  = 1;
            }
        }
        elsif ( $token =~ m/^~~pl/i ) {
            if ($in_proc_sig) {
                $in_proc_sig = 0;
                $line_before = 1;
                $line_after  = 1;
            }
        }
        elsif ( $token eq 'RETURN' ) {
            $line_before = 1;
        }
        elsif ( $token =~ m/^~~comment_/i ) {
            $line_before = $comments->{ lc $token }{newline_before};
            $line_after  = $comments->{ lc $token }{newline_after};
        }

        elsif ( $in_proc_sig eq 'TRIGGER' ) {
            if ( $token eq 'REFERENCING' ) {
                $line_before = 1;
            }
            elsif ( $token eq 'FOR' ) {
                $line_before = 1;
            }
            elsif ( $token =~ m/^(BEFORE|AFTER|INSTEAD)$/i ) {
                if ( @new_tokens and $new_tokens[-1] ne "\n" ) {
                    $line_before = 1;
                }
            }
        }

        if ( 0 == $idx ) {
            $line_before = 0;
        }
        if ( $#tokens == $idx ) {
            $line_after = 0;
        }

        ################################################################
        # Adjust the leading new lines
        if ( $line_before != 0 ) {
            my $count = 0;
            foreach my $i ( 1 .. $#new_tokens ) {
                last if ( $new_tokens[ -$i ] ne "\n" );
                $count++;
            }

            if ( $line_before > 0 and $count < $line_before ) {
                foreach ( $count .. $line_before - 1 ) {
                    push @new_tokens, "\n";
                }
            }
        }

        if ( $token ne "\n" and $token ne '' ) {
            push @new_tokens, $tokens[$idx];
        }

        ################################################################
        # Adjust the trailing new lines
        if ( $line_after != 0 ) {
            my $count = 0;
            foreach my $i ( $idx .. $#tokens ) {
                last if ( $tokens[$i] ne "\n" );
                $count++;
            }

            if ( $line_after > 0 and $count < $line_after ) {
                foreach ( $count .. $line_after - 1 ) {
                    push @new_tokens, "\n";
                }
            }
        }

    }

    return @new_tokens;
}

sub add_indents {
    my ( $self, @tokens ) = @_;
    my @new_tokens;
    my $parens = 0;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token      = uc $tokens[$idx];
        my $next_token = ( $idx < $#tokens ) ? uc $tokens[ $idx + 1 ] : '';
        my $last_token = ( $idx > 0 ) ? uc $tokens[ $idx - 1 ] : '';

        if ( $token eq '(' ) {
            $parens++;
        }
        elsif ( $token eq ')' ) {
            $parens--;
        }

        if ( $token eq "\n" ) {

            push @new_tokens, "\n";

            if ( $next_token ne "\n" ) {

                # Oracle triggers
                my $offset = 0;
                if ( $Dialect->dialect() eq 'Oracle' ) {
                    if ( $next_token =~ m/^(BEFORE|AFTER|INSTEAD|REFERENCING|FOR)$/ ) {
                        $offset = 1;
                    }
                }
                my $indent = $indenter->to_indent( $parens + $offset );
                #push @new_tokens, "-- " . join (', ', scalar @block_stack, $parens, $offset );
                if ($indent) {
                    push @new_tokens, $indent;
                }
            }

        }
        else {

            push @new_tokens, $tokens[$idx];
        }

    }

    return @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
