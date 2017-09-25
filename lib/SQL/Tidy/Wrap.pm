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

    @tokens = grep { defined $_ } @tokens;
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

    # 20170921 - I *think* the following might be close to good enough.
    # The problem, of course, is now to figure out how to make it so.
    #
    # 1. Wrap on boolean operators before comparison operators.
    #     Additionally, wrap boolean operators at the lowest parens count
    #     before moving towards the highest (most deeply nested) parens
    #     count.
    #
    # 3. Wrap on comparison operators before arithmetic operators.
    #
    # 4. Wrap on arithmetic operators. As with boolean operators, wrap
    #     at the lowest parens count before moving towards the highest
    #     parens count.
    #
    # 5. Wrap on concatenation operators.
    #
    # 6. That still leaves the question of where do longish "IN ( ... )"
    #     blocks fit in this?
    #
    # Create an array of arrays. For each array, if it is too long, then
    # take it to the next level of wrapping. Once each array is short
    # enough or all wrapping functions have been exhausted then declare
    # it done, add new lines/indentation and call it wrapped.
    #
    # Each wrapping function needs to know how much initial indent there
    # is, how much to indent the wraps, and which tokens it is operating
    # on. Strings and comments are also needed so that their length may
    # be included in line length calculations.

    my @new_tokens  = ();
    my $indent_size = 1;

    my $base_indent = '';
    if ( @tokens and $tokens[0] =~ $space_re ) {
        $base_indent = shift @tokens;
        push @new_tokens, $base_indent;
    }

    my @start;
    my @start2;
    my @acc;
    my $parens = 0;

    my $idx_when = $self->find_first( 'WHEN', @tokens );
    my $idx_then = $self->find_first( 'THEN', @tokens );

    if (    defined $idx_when
        and $idx_when < 2
        and defined $idx_then
        and $idx_then < $#tokens )
    {

        @start = $self->split_tokens( 'THEN', 2, @tokens );
    }
    else {
        push @start, \@tokens;
    }

    foreach my $line (@start) {

        my ( $pre, $fcn, $post ) = $self->extract_function( 'IN', @{$line} );
        if ( $fcn and @{$fcn}[0] ) {

            my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
            my $line_length = $self->calc_line_length( $strings, $comments, @{$fcn} );
            $indent_size += scalar grep { $_ eq '(' } @{$pre};
            $indent_size -= scalar grep { $_ eq ')' } @{$pre};

            if (    $line_length > $min_line_width
                and $line_length + length($indent) >= $max_line_width )
            {

                while ( @{$fcn}[0] ne '(' ) {
                    push @{$pre}, shift @{$fcn};
                }
                push @{$pre}, shift @{$fcn};
                $indent_size++;

                push @start2, $pre;

                my @lines = $self->wrap_csv(
                    {
                        indent_size => $indent_size,
                        base_indent => $base_indent,
                        strings     => $strings,
                        comments    => $comments,
                        tokens      => $fcn,
                    }
                );

                foreach my $idx ( 0 .. $#lines ) {
                    if ( @{ $lines[$idx] }[0] eq ' ' ) {
                        shift @{ $lines[$idx] };
                    }
                    if ( $idx == $#lines ) {
                        if ( $post and defined @{$post}[0] ) {
                            push @{ $lines[$idx] }, @{$post};
                        }
                    }

                    push @start2, $lines[$idx];
                }
            }
            else {
                push @start2, $line;
            }
        }
        else {
            push @start2, $line;
        }
    }

    foreach my $line (@start2) {

        my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
        my $line_length = $self->calc_line_length( $strings, $comments, @{$line} );

        if (   $line_length < $min_line_width
            or $line_length + length($indent) < $max_line_width )
        {
            push @acc, $line;
        }
        else {

            my %comp_ops = map { $_ => $_ } ( 'AND', 'OR' );
            my @lines = $self->wrap_ops(
                {
                    indent_size => $indent_size + $parens,
                    base_indent => $base_indent,
                    strings     => $strings,
                    comments    => $comments,
                    tokens      => $line,
                    ops         => \%comp_ops,
                }
            );

            foreach my $line (@lines) {
                my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
                my $line_length = $self->calc_line_length( $strings, $comments, @{$line} );
                $parens += scalar grep { $_ eq '(' } @{$line};
                $parens -= scalar grep { $_ eq ')' } @{$line};

                if (   $line_length < $min_line_width
                    or $line_length + length($indent) < $max_line_width )
                {
                    push @acc, $line;
                }
                else {
                    my %comp_ops = map { $_ => $_ } ( '=', '==', '<', '>', '<>', '!=', '>=', '<=' );
                    my @lines = $self->wrap_ops(
                        {
                            indent_size => $indent_size + $parens,
                            base_indent => $base_indent,
                            strings     => $strings,
                            comments    => $comments,
                            tokens      => $line,
                            ops         => \%comp_ops,
                        }
                    );

                    foreach my $line (@lines) {
                        my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
                        my $line_length = $self->calc_line_length( $strings, $comments, @{$line} );
                        $parens += scalar grep { $_ eq '(' } @{$line};
                        $parens -= scalar grep { $_ eq ')' } @{$line};

                        if (   $line_length < $min_line_width
                            or $line_length + length($indent) < $max_line_width )
                        {
                            push @acc, $line;
                        }
                        else {
                            my %math_ops = map { $_ => $_ } ( '+', '-', '*', '/' );
                            # TODO: add the rest of the math ops?
                            # What would that be? Probably not the
                            # modulo.. or would it. Exponent.

                            my @lines = $self->wrap_ops(
                                {
                                    indent_size => $indent_size + $parens,
                                    base_indent => $base_indent,
                                    strings     => $strings,
                                    comments    => $comments,
                                    tokens      => $line,
                                    ops         => \%math_ops,
                                }
                            );

                            foreach my $line (@lines) {
                                my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
                                my $line_length = $self->calc_line_length( $strings, $comments, @{$line} );
                                $parens += scalar grep { $_ eq '(' } @{$line};
                                $parens -= scalar grep { $_ eq ')' } @{$line};

                                if (   $line_length < $min_line_width
                                    or $line_length + length($indent) < $max_line_width )
                                {
                                    push @acc, $line;
                                }
                                else {
                                    my @lines = $self->wrap_ops(
                                        {
                                            indent_size => $indent_size + $parens,
                                            base_indent => $base_indent,
                                            strings     => $strings,
                                            comments    => $comments,
                                            tokens      => $line,
                                            ops         => { '||' => '||' },
                                        }
                                    );

                                    foreach my $line (@lines) {
                                        #my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
                                        #my $line_length = $self->calc_line_length( $strings, $comments, @{$line} );
                                        #$parens += scalar grep { $_ eq '(' } @{$line};
                                        #$parens -= scalar grep { $_ eq ')' } @{$line};

                                        push @acc, $line;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    $parens = 0;
    foreach my $idx ( 0 .. $#acc ) {

        if ( $idx > 0 ) {
            my $indent = $indenter->add_indents( $base_indent, $indent_size + $parens );
            push @new_tokens, "\n", $indent;
        }

        my @ary = @{ $acc[$idx] };
        foreach my $tok (@ary) {
            if ( $tok eq '(' ) {
                $parens++;
            }
            elsif ( $tok eq ')' ) {
                $parens--;
            }
            push @new_tokens, $tok;
        }
    }

    return @new_tokens;
}

sub wrap_ops {
    my ( $self, $args ) = @_;

    my $indent_size = ( defined $args->{indent_size} ) ? $args->{indent_size} : 1;
    my $strings     = $args->{strings};
    my $comments    = $args->{comments};
    my $level       = $args->{level} || 0;
    my $max_level   = $args->{max_level} || 0;
    my @tokens      = @{ $args->{tokens} };
    my %ops         = %{ $args->{ops} };

    my $base_offset = 0;
    my $base_indent = $args->{base_indent};
    if ( not defined $base_indent ) {
        if ( @tokens and $tokens[0] =~ $space_re ) {
            $base_indent = $tokens[0];
            $base_offset = length($base_indent);
        }
        else {
            $base_indent = '';
        }
    }

    my $indent = $indenter->add_indents( $base_indent, $indent_size );
    my $line_length = $self->calc_line_length( $strings, $comments, @tokens ) - $base_offset;
    $indent_size += scalar grep { $_ eq '(' } @tokens;
    $indent_size -= scalar grep { $_ eq ')' } @tokens;

    my @new_tokens;

    if (
        not(    $line_length > $min_line_width
            and $line_length + length($indent) >= $max_line_width
            and ( grep { $ops{$_} } @tokens ) )
        )
    {
        push @new_tokens, \@tokens;
    }
    else {
        my $line_no = 0;
        my $parens  = 0;
        my @temp;

        foreach my $idx ( 0 .. $#tokens ) {
            my $token = uc $tokens[$idx];
            if ( $token eq '(' ) {
                $parens++;
            }
            elsif ( $token eq ')' ) {
                $parens--;
            }
            elsif ( $parens == $level ) {
                if ( exists $ops{$token} ) {

                    # Special case for 'AND' ops:
                    # Do not wrap on "BETWEEN x AND y"
                    # Do not wrap on things like "BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"
                    if ( $token eq 'AND' ) {
                        if ( $idx > 1 and $tokens[ $idx - 2 ] =~ m/^(PRECEDING|FOLLOWING|ROW)$/i ) {
                            # no wrap
                        }
                        elsif ( $idx > 3 and uc $tokens[ $idx - 4 ] eq 'BETWEEN' ) {
                            # no wrap
                        }
                        else {
                            $line_no++;
                        }
                    }
                    else {
                        $line_no++;
                    }
                }
            }
            push @{ $temp[$line_no] }, $tokens[$idx];
        }

        foreach my $idx ( 0 .. $#temp ) {
            unless ( $temp[$idx] ) {
                next;
            }

            if ( $self->find_first( '(', @{ $temp[$idx] } ) ) {

                my @ret = $self->wrap_ops(
                    {
                        indent_size => $indent_size,
                        base_indent => $base_indent,
                        level       => $level + 1,
                        strings     => $strings,
                        comments    => $comments,
                        tokens      => $temp[$idx],
                        ops         => \%ops,
                    }
                );

                foreach my $line (@ret) {
                    push @new_tokens, $line;
                }
            }
            else {
                push @new_tokens, $temp[$idx];
            }
        }
    }
    return @new_tokens;
}

sub wrap_csv {
    my ( $self, $args ) = @_;

    my $indent_size = ( defined $args->{indent_size} ) ? $args->{indent_size} : 1;
    my $strings     = $args->{strings};
    my $comments    = $args->{comments};
    my @tokens      = @{ $args->{tokens} };

    # TODO: allow for "skinny" version (one element per line) vs.
    # "compact" version (current behavior)

    my $base_indent = $args->{base_indent};
    if ( not defined $base_indent ) {
        if ( @tokens and $tokens[0] =~ $space_re ) {
            $base_indent = $tokens[0];
        }
    }

    my $indent = $indenter->add_indents( $base_indent, $indent_size );
    my $line_length = $self->calc_line_length( $strings, $comments, @tokens ) - length($indent);

    my @new_tokens;
    my $idx = 0;

    if (
        not(    $line_length > $min_line_width
            and $line_length + length($base_indent) >= $max_line_width )
        )
    {
        push @new_tokens, \@tokens;
    }
    else {

        foreach my $token (@tokens) {
            $line_length =
                $self->calc_line_length( $strings, $comments, @{ $new_tokens[$idx] }, $token, ',' ) + length($indent);

            if ( $token eq ',' ) {
                # just make sure we don't wrap before the comma
            }
            elsif ( $line_length >= $max_line_width ) {
                $idx++;
            }
            push @{ $new_tokens[$idx] }, $token;
        }
    }
    return @new_tokens;
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

sub regexp_split_tokens {
    my ( $self, $re, $limit, @tokens ) = @_;
    my @return;
    my $idx = 0;

    foreach my $token (@tokens) {
        if ( $token =~ m/$re/i ) {
            if ( $idx < $limit or $limit == 0 ) {
                $idx++;
            }
        }
        push @{ $return[$idx] }, $token;
    }

    return @return;
}

sub split_tokens {
    my ( $self, $key, $limit, @tokens ) = @_;
    my @return;
    my $idx = 0;

    foreach my $token (@tokens) {
        if ( uc $token eq uc $key ) {
            if ( $idx < $limit or $limit == 0 ) {
                $idx++;
            }
        }
        push @{ $return[$idx] }, $token;
    }

    return @return;
}

1;
