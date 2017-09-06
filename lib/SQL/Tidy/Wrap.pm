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
    my @new_tokens;

    my @line = ();

    # TODO: If the line is part of a larger math operation (preceeded by
    # a *, /, +, -) (such as a CASE statement) then the CASE needs to
    # indent an additional level and the math operator needs to be
    # wrapped to the front of the line.

    # accumulate a line worth of tokens then determine the wrap for that line
    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];

        if ( $token eq "\n" ) {
            if ( @line and $line[-1] eq ' ' ) {
                pop @line;
            }
            my @ret = $self->wrap_line( $strings, $comments, @line );
            push @new_tokens, @ret, "\n";
            @line = ();
        }
        elsif ( $idx == $#tokens ) {
            if ( $token ne ' ' ) {
                push @line, $token;
            }
            my @ret = $self->wrap_line( $strings, $comments, @line );
            push @new_tokens, @ret;
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

    my $len = $self->calc_line_length( $strings, $comments, @tokens );

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

    my $indentation = 0;
    if ( $tokens[0] =~ $space_re ) {
        my $token = shift @tokens;

        if ( $token eq ' ' ) {
            $indentation = 1;
        }
        else {
            $indentation = $indenter->indent_length($token);
        }
    }

    if ($indentation) {
        if ( ( $len - $indentation ) <= $min_line_width ) {
            return 0;
        }
    }

    return 1;
}

sub calc_line_length {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return 0 unless (@tokens);

    my $len = 0;

    # Check the first token for indentation
    my $indentation = 0;
    my $ind_token   = '';
    if ( $tokens[0] =~ $space_re ) {
        $ind_token = shift @tokens;

        if ( $ind_token eq ' ' ) {
            $indentation = 1;
            $len         = 1;
        }
        else {
            $indentation = $indenter->indent_length($ind_token);
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
        elsif ( $token =~ m/^~~comment_blk/ and exists $comments->{$token} ) {
            $len += length $comments->{$token};
        }
        else {
            $len += length $token;
        }
    }

    foreach my $idx ( 1 .. $#tokens ) {
        my $token = $tokens[ -$idx ];
        next unless ( defined $token );

        if ( $token eq "\n" ) {
            $len -= length $token;
        }
        elsif ( $token =~ $space_re ) {
            $len -= length $token;
        }
        elsif ( $token =~ m/^~~comment_blk/ and exists $comments->{$token} ) {
            # Single line block comments only count when they are not at the end of the line
            $len -= length $comments->{$token};
        }
        else {
            last;
        }
    }

    return $len;
}

sub wrap_line {
    my ( $self, $strings, $comments, @tokens ) = @_;

    if ( not @tokens ) {
        return @tokens;
    }
    elsif ( not $self->line_needs_wrapping( $strings, $comments, @tokens ) ) {
        return @tokens;
    }

    my @new_tokens = $self->_wrap_line( $strings, $comments, @tokens );

    # TODO: If needed, THIS is the place to iterate the overly long line...

    return @new_tokens;
}

sub _wrap_line {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return @tokens unless (@tokens);

    my @new_tokens = ();

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = $tokens[0];
    }

    my $wrapped = 0;

    # TODO: IF this is called more than once, or processes a WHEN
    # ... THEN (or decode, or ???) then there is the matter of adjusting
    # the indent based on the kind of line being wrapped. Initial line
    # from wrapped lines get one or two additional indents while
    # following wrapped lines may get none (depending on the kind of wrap).

    # For WHEN ... THEN
    # Wrap on THEN IIF it will make the left-hand side short enough
    # AND the right-hand side is longer than x tokens OR y characters
    if ( not $wrapped ) {
        my @temp;
        ( $wrapped, @temp ) = $self->wrap_when_then( $strings, $comments, @tokens );
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }

    # For ... AND|OR ... AND|OR ...
    if ( not $wrapped ) {
        my @temp;
        ( $wrapped, @temp ) = $self->wrap_boolean( $strings, $comments, @tokens );
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }

    # IN clauses
    # For IN clauses, if the number of the items in the list is long
    # enough then wrap the list.
    if ( not $wrapped ) {
        my @temp;
        ( $wrapped, @temp ) = $self->wrap_in_clause( $strings, $comments, @tokens );
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }

    # "Balanced Parens"
    # IIF there are groups of tokens that are surrounded by parens and
    # the spaces between the parens are either math, boolean, or
    # concatenation operators then wrap before the operators.
    if ( not $wrapped ) {
        my @temp;
        ( $wrapped, @temp ) = $self->wrap_balanced_parens( $strings, $comments, @tokens );
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }

    # Wrap concatenated strings
    if ( not $wrapped ) {
        my @temp;
        ( $wrapped, @temp ) = $self->wrap_str_concat( $strings, $comments, @tokens );
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }

    # Wrap parenthetic_list
    # Much like "wrap IN" above but for things other than IN
    if ( not $wrapped ) {
        my @temp;
        ( $wrapped, @temp ) = $self->wrap_paren_list( $strings, $comments, @tokens );
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }

    if ($wrapped) {
        if ( $base_indent and $new_tokens[0] !~ $space_re ) {
            unshift @new_tokens, $base_indent;
        }
    }
    else {
        @new_tokens = @tokens;
    }

    return grep { $_ ne '' } @new_tokens;
}

sub wrap_in_clause {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return ( 0, @tokens ) unless (@tokens);

    my $wrapped = 0;
    my @new_tokens;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }

    # TODO: Consider if the IN list consists of lots of short items
    # such as small integers, or four character codes, or ... then
    # wrap them multiple items per line.

    if ( not $wrapped and $self->find_first( 'IN', @tokens ) ) {

        my ( $pre, $fcn, $post ) = $self->extract_function( 'IN', @tokens );

        if ( $#$fcn > 4 ) {

            push @new_tokens, @{$pre};

            my $parens = 0;
            foreach my $idx ( 0 .. $#$fcn ) {
                my $token = $fcn->[$idx];
                next unless ( defined $token );

                my $next_token = ( $idx < $#$fcn ) ? $fcn->[ $idx + 1 ] : '';

                push @new_tokens, $token;

                if ( $token eq '(' ) {
                    $parens++;
                    if ( $parens == 1 ) {
                        push @new_tokens, "\n", $indenter->add_indents( $base_indent, $parens + 1 );
                        if ( $next_token =~ $space_re ) {
                            $fcn->[ $idx + 1 ] = undef;
                        }
                    }
                }
                elsif ( $token eq '(' ) {
                    $parens--;
                }

                if ( $token eq ',' and $parens == 1 ) {
                    push @new_tokens, "\n", $indenter->add_indents( $base_indent, $parens + 1 );
                    if ( $next_token =~ $space_re ) {
                        $fcn->[ $idx + 1 ] = undef;
                    }
                }
            }

            push @new_tokens, @{$post};
            $wrapped = 1;
        }
    }
    return ( $wrapped, @new_tokens );
}

sub wrap_when_then {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return ( 0, @tokens ) unless (@tokens);

    my $wrapped = 0;
    my @new_tokens;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }

    my $idx_when = $self->find_first( 'WHEN', @tokens );
    my $idx_then = $self->find_first( 'THEN', @tokens );

    if (    defined $idx_when
        and $idx_when < 2
        and defined $idx_then
        and $idx_then < $#tokens )
    {

        my @pre;
        my @post;

        foreach my $token (@tokens) {
            if ( @pre and uc $pre[-1] eq 'THEN' ) {
                push @post, $token;
            }
            else {
                push @pre, $token;
            }
        }

        if ( not $self->line_needs_wrapping( $strings, $comments, @pre ) ) {
            my $len = $self->calc_line_length( $strings, $comments, @post );
            if ( scalar @post > 4 or $len > 40 ) {
                # wrap
                push @new_tokens, @pre;
                push @new_tokens, "\n", $indenter->add_indents( $base_indent, 1 );
                if ( $post[0] eq ' ' ) {
                    shift @post;
                }

                push @new_tokens, @post;
                $wrapped = 1;
            }
        }
    }
    return ( $wrapped, @new_tokens );
}

sub wrap_balanced_parens {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return ( 0, @tokens ) unless (@tokens);

    my $wrapped = 0;
    my @new_tokens;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }

    push @new_tokens, $base_indent;
    my %test = map { $_ => 1 } ( '+', '-', '*', '/', 'AND', 'OR', '||' );

    my @idxs;
    my @ary = $self->extract_balanced_parens(@tokens);
    if ( scalar @ary > 2 ) {

        my @temp;
        foreach my $idx ( 0 .. $#ary ) {
            my @toks = @{ $ary[$idx] };
            if ( $toks[0] eq '(' ) {
                push @temp, @toks;
                push @idxs, $idx;
            }
            else {

                foreach my $ti ( 0 .. $#toks ) {
                    my $token = $toks[$ti];
                    next unless ( defined $token );
                    if ( exists $test{ uc $token } ) {
                        push @temp, "\n", $indenter->add_indents( $base_indent, 1 );
                        $wrapped = 1;
                    }
                    if ( defined $token ) {
                        push @temp, $token;
                    }
                }
            }
        }

        if ( not $wrapped and scalar @ary < 4 and scalar @idxs == 1 ) {
            # if not wrapped
            # and there are three (or fewer) @ary elements
            # and only one is wrapped in parens
            # ... we *could* recurse this... but that might be crazy
            @temp = ();
            foreach my $idx ( 0 .. $#ary ) {
                if ( $idx != $idxs[0] ) {
                    push @temp, @{ $ary[$idx] };
                }
                else {
                    my @toks = @{ $ary[$idx] };

                    # Strip the wrapping parens and re-try the wrapping
                    push @temp, '(', "\n", $indenter->add_indents( $base_indent, 1 );
                    shift @toks;
                    if ( $toks[0] eq ' ' ) {
                        shift @toks;
                    }
                    pop @toks;

                    my @ary2 = $self->extract_balanced_parens(@toks);
                    if ( scalar @ary2 > 2 ) {
                        foreach my $idx2 ( 0 .. $#ary2 ) {
                            my @toks2 = @{ $ary2[$idx2] };
                            if ( $toks2[0] eq '(' ) {
                                push @temp, @toks2;
                            }
                            else {
                                foreach my $ti ( 0 .. $#toks2 ) {
                                    my $token = $toks2[$ti];
                                    if ( exists $test{ uc $token } ) {
                                        push @temp, "\n", $indenter->add_indents( $base_indent, 1 );
                                        $wrapped = 1;
                                    }
                                    push @temp, $token;
                                }
                            }
                        }
                    }
                    push @temp, ')';
                }
            }
        }
        if ($wrapped) {
            push @new_tokens, @temp;
        }
    }
    if ($wrapped) {
        return ( $wrapped, @new_tokens );
    }
    else {
        return ( 0, @tokens );
    }
}

sub wrap_str_concat {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return ( 0, @tokens ) unless (@tokens);

    my $wrapped = 0;
    my @new_tokens;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }
    my $indent = $indenter->add_indents( $base_indent, 1 );

    if ( $self->find_first( '||', @tokens ) ) {

        foreach my $token (@tokens) {

            if ( $token eq '||' ) {
                push @new_tokens, "\n", $indent;
            }

            if ( scalar @new_tokens > 1 and $new_tokens[-2] eq "\n" ) {
                if ( $token !~ $space_re ) {
                    push @new_tokens, $token;
                }
            }
            else {
                push @new_tokens, $token;
            }
        }
        $wrapped = 1;
    }

    return ( $wrapped, @new_tokens );
}

sub wrap_boolean {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return ( 0, @tokens ) unless (@tokens);

    my $wrapped = 0;
    my @new_tokens;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }
    my $indent = $indenter->add_indents( $base_indent, 1 );

    my $do_wrap    = 0;
    my $bool_count = 0;
    my $tokn_count = scalar @tokens;
    foreach my $token (@tokens) {
        if ( uc $token eq 'AND' ) {
            if ( not( scalar @tokens > 1 and uc $tokens[-2] eq 'BETWEEN' ) ) {
                $bool_count++;
            }
        }
        elsif ( uc $token eq 'OR' ) {
            $bool_count++;
        }
        elsif ( $token eq '(' ) {
            $tokn_count--;
        }
        elsif ( $token eq ')' ) {
            $tokn_count--;
        }
        # TODO so we need to account for mathops?
    }

    if ( $bool_count and $tokn_count > 6 and ( $bool_count / ( $tokn_count - 3 ) ) > 0.2 ) {
        # We're going to consider the line mostly boolean.
        $do_wrap = 1;
    }

    # where a = b and c = d
    # 1/(8-3) = 1/5 = 0.2
    # where a = b and c = d and e = f
    # 2/(12-3) = 2/9 =~ 0.222
    # where a = b and c = d and e = f and g = h
    # 3/(16-3) = 3/13 =~ 0.231
    # where a = b and c = d and e = f and g = h and i = j
    # 4/(20-3) = 4/17 =~ 0.235

    if ($do_wrap) {

        my $parens = 0;
        push @new_tokens, $base_indent;

        foreach my $t (@tokens) {
            if ( $t eq '(' ) {
                $parens++;
                $indent = $indenter->add_indents( $base_indent, $parens + 1 );
            }
            elsif ( $t eq ')' ) {
                $parens--;
                $indent = $indenter->add_indents( $base_indent, $parens + 1 );
            }

            if ( scalar @new_tokens > 1 and $new_tokens[-2] eq "\n" ) {
                if ( $t !~ $space_re ) {
                    push @new_tokens, $t;
                }
            }
            else {
                if ( uc $t eq 'AND' ) {
                    if ( scalar @new_tokens > 1 ) {
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
                    else {
                        push @new_tokens, "\n", $indent;
                    }
                }
                elsif ( uc $t eq 'OR' ) {
                    push @new_tokens, "\n", $indent;
                }
                push @new_tokens, $t;
            }
        }
        $wrapped = 1;
    }

    return ( $wrapped, @new_tokens );
}

sub wrap_paren_list {
    my ( $self, $strings, $comments, @tokens ) = @_;

    return ( 0, @tokens ) unless (@tokens);

    my $wrapped = 0;
    my @new_tokens;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
    }
    my $indent = $indenter->add_indents( $base_indent, 1 );

    my $do_wrap = 0;

    if ( join( ' ', @tokens ) =~ m/ +\((.+,){4}.+\)/i ) {
        $do_wrap = 1;
    }

    # Or lists with fewer than four items that are none-the-less rather long...

    if ($do_wrap) {
        # We appear to have a " ( list, of, four or more, things )"

        # TODO: How to deal with nested parens... or two sets of parens in the same line
        # if '(' then "(", "\n", indent++
        # if ',' then ",", "\n", indent
        # if ')' then ")", "\n", indent--

        my $parens = 0;
        push @new_tokens, $base_indent;

        foreach my $t (@tokens) {
            if ( scalar @new_tokens > 1 and $new_tokens[-2] eq "\n" ) {
                if ( $t !~ $space_re ) {
                    push @new_tokens, $t;
                }
            }
            else {
                push @new_tokens, $t;
            }

            if ( $t eq ',' ) {
                push @new_tokens, "\n", $indent;
            }
            elsif ( $t eq '(' ) {
                $parens++;
                $indent = $indenter->add_indents( $base_indent, $parens + 1 );
                push @new_tokens, "\n", $indent;
            }
            elsif ( $t eq ')' ) {
                $parens--;
                $indent = $indenter->add_indents( $base_indent, $parens + 1 );
                # TODO: To wrap after the closing parens or not to wrap after the closing parens...
            }
        }
        $wrapped = 1;
    }

    return ( $wrapped, @new_tokens );
}

sub extract_balanced_parens {
    my ( $self, @tokens ) = @_;

=pod
should return:

list of tokens that have a function x
( parm parm parm nested-function x ( parm parm ) parm )
plus another function x
( parm parm )
and then some other stuff

=cut

    my @return;
    my @ary     = ();
    my $parens  = 0;
    my $idx_ret = 0;

    foreach my $idx ( 0 .. $#tokens ) {

        if ( $tokens[$idx] eq '(' ) {
            if ( $parens == 0 and @ary ) {
                push @{ $return[$idx_ret] }, $_ for @ary;
                $idx_ret++;
                @ary = ();
            }
            $parens++;
        }

        push @ary, $tokens[$idx];

        if ( $tokens[$idx] eq ')' ) {
            $parens--;
            if ( $parens == 0 and @ary ) {
                push @{ $return[$idx_ret] }, $_ for @ary;
                $idx_ret++;
                @ary = ();
            }
        }

    }

    if (@ary) {
        push @{ $return[$idx_ret] }, $_ for @ary;
    }

    return @return;
}

sub extract_function {
    my ( $self, $function, @tokens ) = @_;

    # extract the first instance of a function from a list of tokens

    my @pre    = ();
    my @post   = ();
    my @fcn    = ();
    my $parens = 0;
    my $idx_end;

    my ($idx_start) = $self->find_first( $function, @tokens );

    if ( defined $idx_start ) {
        foreach my $idx ( $idx_start .. $#tokens ) {

            if ( $tokens[$idx] eq '(' ) {
                $parens++;
            }
            elsif ( $tokens[$idx] eq ')' ) {
                $parens--;
                if ( $parens == 0 ) {
                    $idx_end = $idx;

                    if ( $idx_start > 0 ) {
                        @pre = @tokens[ 0 .. $idx_start - 1 ];
                    }

                    @fcn = @tokens[ $idx_start .. $idx_end ];

                    if ( $idx_end < $#tokens ) {
                        @post = @tokens[ $idx_end + 1 .. $#tokens ];
                    }
                    last;
                }
            }
        }
    }
    else {
        @pre = @tokens;
    }

    return ( \@pre, \@fcn, \@post );
}

sub find_first {
    my ( $self, $token, @tokens ) = @_;
    $token = uc $token;

    foreach my $idx ( 0 .. $#tokens ) {
        if ( uc $tokens[$idx] eq $token ) {
            return $idx;
        }
    }
    undef;
}

sub find_next {
    my ( $self, $token, $start, @tokens ) = @_;
    $token = uc $token;

    if ( $start < $#tokens ) {
        foreach my $idx ( $start .. $#tokens ) {
            if ( uc $tokens[$idx] eq $token ) {
                return $idx;
            }
        }
    }
    undef;
}

sub format_window_fcn {
    my ( $self, @line ) = @_;

    return @line unless (@line);

    my @new_tokens;
    my $parens = 0;

    my $base_indent = '';
    if ( @line and $line[0] =~ $space_re ) {
        $base_indent = $line[0];
    }

    foreach my $idx ( 0 .. $#line ) {
        my $token = $line[$idx];

        if ( $token eq '(' ) {
            $parens++;
        }
        elsif ( $token eq ')' ) {
            $parens--;
        }

        # Note: skip the first to ensure we don't re-wrap anything we shouldn't
        if ( $idx > 1 and $idx + 1 < $#line ) {

            if ( uc $line[ $idx + 1 ] eq 'BY' ) {

                if ( $new_tokens[-1] eq ' ' ) {
                    $new_tokens[-1] = undef;
                }
                my $offset = $parens;
                $offset ||= 1;
                push @new_tokens, "\n", $indenter->add_indents( $base_indent, $offset );
            }
        }
        push @new_tokens, $token;
    }

    return grep { defined $_ } @new_tokens;
}

1;
