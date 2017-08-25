package SQL::Tidy::Wrap;
use strict;
use warnings;

use SQL::Tidy::Indent;

=head1 NAME

SQL::Tidy::Wrap

=head1 SYNOPSIS

Line wrapping logic.

=head1 DESCRIPTION

=head1 METHODS

=over

=cut

my $indenter;
my $space_re;
my $max_line_width;
my $min_line_width;

=item new

Create, and return, a new instance of this

=cut

sub new {
    my ( $this, $args ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    $indenter       = SQL::Tidy::Indent->new($args);
    $space_re       = $args->{space_re};
    $max_line_width = $args->{max_line_width};
    $min_line_width = $args->{min_line_width};

    return $self;
}

sub wrap_lines {
    my ( $self, $strings, $comments, @tokens ) = @_;
    my @new_tokens = @tokens;

    foreach ( 0 .. 3 ) {
        @new_tokens = $self->_wrap_lines( $strings, $comments, @new_tokens );
    }

    return @new_tokens;
}

sub _wrap_lines {
    my ( $self, $strings, $comments, @tokens ) = @_;

    # just in case recursion tanks
    my @new_tokens;
    my @line = ();

    # accumulate a line worth of tokens then determine the wrap for that line
    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];

        if ( $token eq "\n" ) {
            my @ret = $self->wrap_line( 1, $strings, $comments, @line );
            push @new_tokens, @ret;
            if ( $token eq "\n" ) {
                push @new_tokens, "\n";
            }
            @line = ();
        }
        elsif ( $idx == $#tokens ) {
            push @line, $token;
            my @ret = $self->wrap_line( 1, $strings, $comments, @line );
            push @new_tokens, @ret;
            if ( $token eq "\n" ) {
                push @new_tokens, "\n";
            }
            @line = ();
        }
        else {
            push @line, $token;
        }

    }
    return grep { $_ ne '' } @new_tokens;
}

sub line_needs_wrapping {
    my ( $self, $strings, $comments, @tokens ) = @_;

    # Since sane wrapping may be a wee bit complicated, and most lines
    # shouldn't need wrapping, first check to see if wrapping is even
    # needed.

    return 0 unless (@tokens);

    my $len = 0;

    # Check the first token for indentation
    my $indentation = 0;
    if ( $tokens[0] =~ $space_re ) {
        my $token = shift @tokens;

        if ( $token eq ' ' ) {
            $indentation = 1;
            $len         = 1;
        }
        else {
            $indentation = $indenter->indent_length($token);
            $len         = $indentation;
        }
    }

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        next unless ( defined $token );

        if ( $token =~ m/^~~string/ and exists $strings->{$token} ) {
            $len += length $strings->{$token};
        }
        elsif ( $token =~ m/^~~comment_eol/ and exists $comments->{$token} ) {
            # Nothing... End-of-line comments don't [currently] count
        }
        elsif ( $token =~ m/^~~comment_blk/ and exists $comments->{$token} and $idx != $#tokens ) {
            # Single line block comments only count when they are not at the end of the line
            $len += length $comments->{$token};
        }
        else {
            $len += length $token;
        }
    }

    if ( $len <= $max_line_width ) {
        return 0;
    }

    # If the first token is white space then check the minimum line
    # size. We really want to avoid the scenario where things are so
    # deeply nested that they eventually wrap
    #                                                        on almost
    #                                                        every
    #                                                        single
    #                                                        token
    if ($indentation) {
        if ( ( $len - $indentation ) <= $min_line_width ) {
            return 0;
        }
    }

    return 1;
}

sub wrap_line {
    my ( $self, $indent_by, $strings, $comments, @tokens ) = @_;

    if ( not @tokens ) {
        return @tokens;
    }
    elsif ( !$self->line_needs_wrapping( $strings, $comments, @tokens ) ) {
        return @tokens;
    }

    my @new_tokens = ();

    # So line wrapping is needed...
    # - String concatenating should wrap on the '||' if used...
    # - Function calls should be kept together if possible (wrap between calls)?
    # - Wrap before boolean operators AND/OR except when AND is part of a function (e.g. "BETWEEN ( x AND y )")
    # - Parens should be considered

    # if IN then wrap after "IN (" and commas
    # if BOOLEAN then wrap before AND/OR

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }
    my $indent = $indenter->add_indents( $base_indent, $indent_by );
    push @new_tokens, $base_indent;

    if (@tokens) {
        my $token   = uc $tokens[0];
        my $wrapped = 0;

        if ( not $wrapped and uc $tokens[0] eq 'IF' or uc $tokens[0] eq 'WHEN' ) {    # or $token eq 'CASE'

            # Only try splitting on THEN if it isn't the last token
            if ( ( grep { uc $_ eq 'THEN' } @tokens ) and uc $tokens[-1] ne 'THEN' ) {
                # WHEN ... THEN ...
                my @ary;
                while ( uc $tokens[0] ne 'THEN' ) {
                    my $t = shift @tokens;
                    push @ary, $t;
                }

                my $t = shift @tokens;
                push @ary, $t;                                                        # grab the 'THEN'

                my @ret = $self->wrap_line( 2, $strings, $comments, @ary );
                push @new_tokens, @ret, "\n";

                if ( $tokens[0] eq ' ' ) {
                    shift @tokens;
                }

                @ret = $self->wrap_line( 0, $strings, $comments, $indent, @tokens );
                push @new_tokens, @ret;

                $wrapped = 1;
            }
        }

        if ( not $wrapped and grep { $_ =~ m/^(AND|OR)$/i } @tokens ) {
            my $parens = 0;

            foreach my $t (@tokens) {
                if ( $t eq '(' ) {
                    $parens++;
                }
                elsif ( $t eq ')' ) {
                    $parens--;
                }
                elsif ( $t =~ m/^(AND|OR)$/i ) {
                    # If the parens is zero (not wanting to break up function calls, etc. if not needed
                    # and it isn't part of a 'between x and y' thing

                    if ( $parens == 0 ) {

                        foreach my $i ( 1 .. $#new_tokens ) {
                            my $lastok = $new_tokens[ -$i ];

                            next if ( $lastok =~ $space_re );
                            next if ( $lastok =~ /^~~comment/i );
                            next if ( $lastok eq "\n" );
                            if ( uc $lastok ne 'BETWEEN' ) {

                                push @new_tokens, "\n", $indent;
                                $wrapped = 1;
                            }
                            last;
                        }

                    }
                }
                push @new_tokens, $t;
            }
        }

        if ( not $wrapped and grep { $_ eq '||' } @tokens ) {

            foreach my $t (@tokens) {

                if ( $t eq '||' ) {
                    push @new_tokens, "\n", $indent;
                }

                if ( scalar @new_tokens > 1 and $new_tokens[-2] eq "\n" ) {
                    if ( $t !~ $space_re ) {
                        push @new_tokens, $t;
                    }
                }
                else {
                    push @new_tokens, $t;
                }
            }
            $wrapped = 1;
        }

        #      if ( not $wrapped and join( ' ', @tokens ) =~ m/ +\((.+,){4}.+\)/i ) {
        #          # We appear to have a " ( list, of, four or more, things )"
        #
        #          # TODO: How to deal with nested parens... or two sets of parens in the same line
        #          # if '(' then "(", "\n", indent++
        #          # if ',' then ",", "\n", indent
        #          # if ')' then ")", "\n", indent--
        #
        #          my $parens = 0;
        #
        #          foreach my $t (@tokens) {
        #              if ( scalar @new_tokens > 1 and $new_tokens[-2] eq "\n" ) {
        #                  if ( $t !~ $space_re ) {
        #                      push @new_tokens, $t;
        #                  }
        #              }
        #              else {
        #                  push @new_tokens, $t;
        #              }
        #
        #              if ( $t eq ',' ) {
        #                  push @new_tokens, "\n", $indent;
        #              }
        #              elsif ( $t eq '(' ) {
        #                  $parens++;
        #                  $indent = $indenter->add_indents( $base_indent, $indent_by + $parens );
        #                  push @new_tokens, "\n", $indent;
        #              }
        #              elsif ( $t eq ')' ) {
        #                  $parens--;
        #                  $indent = $indenter->add_indents( $base_indent, $indent_by + $parens );
        #                  # TODO: To wrap after the closing parens or not to wrap after the closing parens...
        #              }
        #          }
        #          $wrapped = 1;
        #      }

        if ( not $wrapped ) {
            push @new_tokens, @tokens;
        }
    }

    return grep { $_ ne '' } @new_tokens;
}

1;
