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

my $Dialect;
my $indenter;

=item new

Create, and return, a new instance of this

=cut

sub new {
    my ( $this, $args ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    $Dialect  = SQL::Tidy::Dialect->new($args);
    $indenter = SQL::Tidy::Indent->new($args);

    return $self;
}

sub format_ddl {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens = @tokens;

    @new_tokens = $self->unquote_identifiers(@new_tokens);
    @new_tokens = $self->capitalize_keywords(@new_tokens);

    @new_tokens = $self->add_vspace( $comments, @tokens );
    @new_tokens = $self->add_indents(@new_tokens);

    return @new_tokens;
}

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    my @new_tokens;
    my %keywords = $Dialect->ddl_keywords();
    my $stu_re   = $Dialect->safe_ident_re();

    foreach my $token (@tokens) {

        if ( exists $keywords{ uc $token } ) {
            $token = $keywords{ uc $token }{word};
        }
        elsif ( $token =~ $stu_re ) {
            $token = lc $token;
        }

        push @new_tokens, $token;
    }

    return @new_tokens;
}

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;
    return @tokens;    # TODO remove me
    my @new_tokens;

    return @new_tokens;
}

sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens;
    my $parens      = 0;
    my $in_proc_sig = 0;
    my $in_view_sig = 0;
    my $current     = '';

    my %h = (
        'CREATE'  => 1,
        'ALTER'   => 1,
        'DROP'    => 1,
        'COMMENT' => 1,
        'GRANT'   => 1,
        'REVOKE'  => 1,
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
            if ( $token eq 'FUNCTION' or $token eq 'PROCEDURE' ) {
                $in_proc_sig = 1;
            }
            elsif ( $token eq 'VIEW' ) {
                $in_view_sig = 1;
            }
        }

        if ( $token eq '(' ) {
            $parens++;
            if ( $in_proc_sig and $parens == 1 ) {
                $line_after = 1;
            }
            elsif ( $in_view_sig and $parens == 1 ) {
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
        }

        elsif ( $token eq ';' ) {
            $current    = 0;
            $line_after = 1;
        }
        elsif ( $token eq '/' ) {
            $line_after = 1;
        }
        elsif ( $token eq 'CREATE' ) {
            $line_before = 2;
        }
        elsif ( $token eq 'ALTER' ) {
            $line_before = 2;
        }
        elsif ( $token eq 'DROP' ) {
            $line_before = 2;
        }
        elsif ( $token eq 'COMMENT' ) {
            $line_before = 2;
        }
        elsif ( $token eq 'AS' ) {
            if ( $in_proc_sig and $parens == 0 ) {
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
            if ( $in_proc_sig and $parens == 0 ) {
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
                my $indent = $indenter->to_indent($parens);
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
