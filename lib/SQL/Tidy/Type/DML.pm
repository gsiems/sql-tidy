package SQL::Tidy::Type::DML;
use base 'SQL::Tidy::Type';
use strict;
use warnings;

use SQL::Tidy::Dialect;
use SQL::Tidy::Indent;
use SQL::Tidy::Wrap;

=head1 NAME

SQL::Tidy::Type::DML

=head1 SYNOPSIS

Tag and untag blocks of SQL queries (DML)

=head1 DESCRIPTION

=head1 METHODS

=over

=cut

my $Dialect;
my $indenter;
my $space_re;
my $case_folding;
my $Wrapper;

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
    $Wrapper      = SQL::Tidy::Wrap->new($args);

    return $self;
}

=item tag ( tokens )

Replaces SQL query statements (DML blocks as opposed to PL-code, etc.)
with a tag and stores the original DML in a reference hash.

We do this because it appears that SQL statements need different rules
for formatting, etc.

Returns a hash-ref of the DML tags and the modified list of tokens.

=cut

sub tag {
    my ( $self, @tokens ) = @_;

    my %dml;
    my $dml_key;
    my @new_tokens;
    my $is_grant = 0;
    my $is_pl    = '';
    my $parens   = 0;

    foreach my $idx ( 0 .. $#tokens ) {

        my $token = $tokens[$idx];
        #my $next_token  = ( $idx < $#tokens ) ? uc $tokens[ $idx + 1 ] : '';
        #my $third_token = ( $idx + 1 < $#tokens ) ? uc $tokens[ $idx + 2 ] : '';
        my $last_token = ( $idx > 0 ) ? uc $tokens[ $idx - 1 ] : '';

        # Extract the DML blocks
        if ($dml_key) {

            if ( $token eq '(' ) {
                $parens++;
            }
            elsif ( $token eq ')' ) {
                $parens--;
                if ( $parens < 0 ) {
                    $dml_key = undef;
                }
            }
            elsif ( $token eq ';' ) {
                $dml_key = undef;
            }
        }
        elsif ( not $is_grant and not $is_pl and $token =~ m/^(WITH|SELECT|INSERT|UPDATE|DELETE|MERGE)$/i ) {
            # If the token is (WITH|SELECT|INSERT|UPDATE|DELETE|MERGE),
            # and we aren't already in a statement then it looks like
            # we are starting a statement.
            $dml_key = '~~dml_' . sprintf( "%04d", $idx );
            push @new_tokens, $dml_key;
            $parens = 0;
        }

        if ($dml_key) {
            push @{ $dml{$dml_key} }, $token;
        }
        else {
            push @new_tokens, $token;
        }

        # Ensure that "GRANT ... TO user [WITH GRANT OPTION]" does not
        # get partially tagged as DML
        # Also ensure that trigger definitions don't get caught either
        if ( $token eq 'GRANT' or $token eq 'REVOKE' ) {
            $is_grant = 1;
        }
        elsif ( $token eq 'TRIGGER' ) {
            $is_pl = $token;
        }
        elsif ( $is_grant and $token eq ';' ) {
            $is_grant = 0;
        }
        elsif ( $is_pl eq 'TRIGGER' and $token eq 'BEGIN' ) {
            $is_pl = '';
        }

    }

    my @key_queue = ( keys %dml );

    while (@key_queue) {
        my $dml_key = shift @key_queue;
        my ( $new_dml, @dml_tokens ) = $self->tag_sub_dml( $dml_key, @{ $dml{$dml_key} } );
        if ( scalar keys %{$new_dml} ) {
            # There were sub-queries found.
            # Update the tokens for the parent DML and place the sub-queries
            # in the queue to check them for sub queries
            foreach my $sub_dml_key ( keys %{$new_dml} ) {
                $dml{$dml_key}     = \@dml_tokens;
                $dml{$sub_dml_key} = $new_dml->{$sub_dml_key};
                push @key_queue, $sub_dml_key;
            }
        }
    }

    return ( \%dml, grep { $_ ne '' } @new_tokens );
}

=item tag_sub_dml ( parent_key, tokens )

Replaces sub-query statements for the parent query (parent_key)
with a tag and stores the original DML in a reference hash.

Used for recursively separating all sub-queries to facilitate
formatting.

Returns a hash-ref of the DML tags and the modified list of tokens.

=cut

sub tag_sub_dml {
    my ( $self, $parent_key, @tokens ) = @_;

    my @new_tokens;
    my $dml_key;
    my $parens = 0;
    my %dml;

    foreach my $idx ( 0 .. $#tokens ) {

        my $token       = $tokens[$idx];
        my $next_token  = ( $idx < $#tokens ) ? uc $tokens[ $idx + 1 ] : '';
        my $third_token = ( $idx + 1 < $#tokens ) ? uc $tokens[ $idx + 2 ] : '';
        my $last_token  = ( $idx > 0 ) ? uc $tokens[ $idx - 1 ] : '';

        # Extract the DML blocks
        if ($dml_key) {

            if ( $token eq '(' ) {
                $parens++;
            }
            elsif ( $token eq ')' ) {
                $parens--;
                if ( $parens < 0 ) {
                    $dml_key = undef;
                }
            }
            elsif ( $token eq ';' ) {
                $dml_key = undef;
            }
            elsif ( $token eq 'WHEN' ) {
                if ( $next_token eq 'MATCHED' or ( $next_token eq 'NOT' and $third_token eq 'MATCHED' ) ) {
                    $dml_key = undef;
                }
            }
        }
        elsif ( $idx > 0 and $token =~ m/^(WITH|SELECT|INSERT|UPDATE|DELETE|MERGE)$/i ) {
            # If the token is (WITH|SELECT|INSERT|UPDATE|DELETE|MERGE),
            # and we aren't already in a statement then it looks like
            # we are starting a statement.
            $dml_key = join( '.', $parent_key, sprintf( "%04d", $idx ) );
            push @new_tokens, $dml_key;
            $parens = 0;
        }

        if ($dml_key) {
            push @{ $dml{$dml_key} }, $token;
        }
        else {
            push @new_tokens, $token;
        }
    }

    return ( \%dml, grep { $_ ne '' } @new_tokens );
}

=item untag_dml ( dml, tokens )

Takes the hash of dml tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag {
    my ( $self, $dmls, @tokens ) = @_;
    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~dml_/ ) {
            my @ary = @{ $dmls->{$token} };

            # Determine the indent to add to each line base on the
            # indent of the dml tag
            my $indent = (@new_tokens) ? $new_tokens[-1] : '';
            if ( $indent =~ $space_re ) {
                # Bump the indent of each indentation token in the dml
                # block (excepting the first of course)
                foreach my $dml_idx ( 0 .. $#ary ) {
                    my $dml_tok = $ary[$dml_idx];

                    if ( $dml_idx > 0 and $ary[ $dml_idx - 1 ] eq "\n" ) {
                        if ( $dml_tok =~ $space_re ) {
                            $dml_tok = $indent . $dml_tok;
                        }
                        else {
                            push @new_tokens, $indent;
                        }
                    }
                    push @new_tokens, $dml_tok;
                }
            }
            else {
                # No indentation changes needed
                push @new_tokens, @ary;
            }
        }
        else {
            push @new_tokens, $token;
        }
    }

    # Recursively untag sub queries
    if ( grep { $_ =~ m/^~~dml_/ } @new_tokens ) {
        @new_tokens = $self->untag( $dmls, @new_tokens );
    }

    return @new_tokens;
}

=item capitalize_keywords ( tokens )


=cut

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    my %keywords = $Dialect->dml_keywords();
    return $self->_capitalize_keywords( \%keywords, @tokens );
}

=item unquote_identifiers ( tokens )


=cut

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;

    my %keywords    = $Dialect->dml_keywords();
    my $stu_re      = $Dialect->safe_ident_re();
    my %pct_attribs = $Dialect->pct_attribs();

    return $self->_unquote_identifiers( \%keywords, \%pct_attribs, $stu_re, $case_folding, @tokens );
}

=item add_vspace ( tokens )

Add vertical spacing (new lines) to the tokens of a DML block

Returns the modified tokens

=cut

sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens;
    my $parens         = 0;
    my $statement_type = '';
    my $sub_clause     = '';
    my @cases;

    my %h = (
        'WITH' => { 'OTHER' => 0 },

        'MERGE' => {
            'USING'  => 1,
            'ON'     => 1,
            'WHEN'   => 1,
            'UPDATE' => 1,
            'INSERT' => 1,
            'WHERE'  => 1,
            'OTHER'  => 2,
        },
        'SELECT' => {
            'INTO'      => 1,
            'FROM'      => 1,
            'PIVOT'     => 1,
            'FOR'       => 1,
            'JOIN'      => 1,
            'ON'        => 1,
            'USING'     => 1,
            'WHERE'     => 1,
            'GROUP'     => 1,
            'ORDER'     => 1,
            'HAVING'    => 1,
            'PARTITION' => 1,
            'UNION'     => 1,
            'INTERSECT' => 1,
            'EXCEPT'    => 1,
            'MINUS'     => 1,
        },
        'INSERT' => { 'VALUES' => 1 },
        'UPDATE' => {
            'SET'    => 1,
            'FROM'   => 1,
            'JOIN'   => 1,
            'ON'     => 1,
            'USING'  => 1,
            'WHERE'  => 1,
            'GROUP'  => 1,
            'ORDER'  => 1,
            'HAVING' => 1,
        },
        'DELETE' => { 'WHERE' => 1, },
    );

=pod

TODO: possibly a multi-pass approach:
    pass 1: only line-break on new clause keywords where parens == 0
    pass 2: with the first tokens in the new lines being the major sub-clause, add additional line-breaks on commas, parens, etc.
    pass 3: ???

=cut

    foreach my $idx ( 0 .. $#tokens ) {
        my $token       = uc $tokens[$idx];
        my $line_before = 0;
        my $line_after  = 0;

        if ( not $statement_type and exists $h{$token} ) {
            $statement_type = $token;
        }

        if ( $token eq '(' ) {
            $parens++;
            if ( $statement_type eq 'INSERT' and 1 == $parens ) {
                $line_after = 1;
            }
        }
        elsif ( $token eq ')' ) {
            $parens--;

            # TODO: when exiting some constructs, do we want to line-feed?

        }
        elsif ( $token eq ',' ) {
            if ( 0 == $parens ) {
                $line_after = 1;
            }
            elsif ( $statement_type eq 'INSERT' and 1 == $parens ) {
                $line_after = 1;
            }
        }
        elsif ( $token =~ m/^~~comment_/i ) {
            $line_before = $comments->{ lc $token }{newline_before};
            $line_after  = $comments->{ lc $token }{newline_after};
        }
        elsif ( $token =~ m/^~~dml_/i ) {
            $line_before = 1;
            $line_after  = 1;
        }
        elsif ( $token eq 'OR' ) {
            $line_before = 1;
            if (@cases) {
                $line_before = 0;
            }
        }
        elsif ( $token eq 'AND' ) {
            $line_before = 1;
            # back-track new tokens looking for 'BETWEEN' in the current line
            if ( scalar @new_tokens > 2 and uc $new_tokens[-2] eq 'BETWEEN' ) {
                $line_before = 0;
            }
            elsif (@cases) {
                $line_before = 0;
            }
        }

        elsif ( $token eq 'GROUP' and @new_tokens and uc $new_tokens[-1] eq 'WITHIN' ) {
            $line_before = 0;

        }
        # TODO: vspace for other...
        else {

            if ( $parens == 0 ) {
                my $test = $token;
                if ( $test =~ m/^(RIGHT|LEFT|CROSS|FULL|NATURAL|INNER|OUTER|JOIN)$/i ) {
                    $test = 'JOIN';
                }

                # TODO: Fix the wrapping of FROM in EXTRACT ... FROM

                if ( exists $h{$statement_type}{$test} ) {
                    if ( $test eq 'JOIN' ) {
                        my $last_token = ( $idx > 0 ) ? uc $tokens[ $idx - 1 ] : '';

                        # Ensure that we aren't twigging on another part of the same join
                        if ( $last_token !~ m/^(RIGHT|LEFT|CROSS|FULL|NATURAL|INNER|OUTER|JOIN)$/i ) {
                            $sub_clause  = $test;
                            $line_before = $h{$statement_type}{$test};
                        }
                    }
                    else {
                        $sub_clause  = $test;
                        $line_before = $h{$statement_type}{$test};
                    }
                }

                if ( exists $h{$statement_type}{$test} ) {
                    $sub_clause = $test;
                }
            }
        }

        # Track whether or not we are in a case structure as we don't
        # currently want to wrap on booleans within the case.
        if ( $token eq 'CASE' ) {
            push @cases, $token;
        }
        elsif ( @cases and $token eq 'END' ) {
            pop @cases;
        }

        ################################################################
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

=item add_indents ()

Add leading indentation to the tokens of a DML block

Returns the modified tokens

=cut

sub add_indents {
    my ( $self, @tokens ) = @_;

    # ASSERTIONS:
    #   - no "spaces" tokens have been added yet
    #   - vertical spacing already done

    my @new_tokens;
    my $parens          = 0;
    my $statement_type  = '';
    my $last_sub_clause = '';
    my @cases;
    my @sc;

    my %h = (
        'WITH'  => { 'OTHER' => 0, },
        'MERGE' => {
            'USING'  => 1,
            'WHEN'   => 1,
            'INSERT' => 2,
            'UPDATE' => 2,
            'SET'    => 2,
            'ON'     => 2,
            'WHERE'  => 1,
            'OTHER'  => 2,
        },
        'SELECT' => {
            'INTO'      => 1,
            'FROM'      => 1,
            'JOIN'      => 1,
            'LEFT'      => 1,
            'RIGHT'     => 1,
            'INNER'     => 1,
            'OUTER'     => 1,
            'FULL'      => 1,
            'CROSS'     => 1,
            'NATURAL'   => 1,
            'WHERE'     => 1,
            'GROUP'     => 1,
            'HAVING'    => 1,
            'ORDER'     => 1,
            'PARTITION' => 1,
            'PIVOT'     => 1,
            'OTHER'     => 2,
            'UNION'     => 0,
            'MINUS'     => 0,
            'EXCEPT'    => 0,
            'ITERSECT'  => 0,
            'SELECT'    => 0,
        },
        'INSERT' => {
            'VALUES' => 1,
            'OTHER'  => 1,
        },
        'UPDATE' => {
            'SET'   => 1,
            'WHERE' => 1,
            'OTHER' => 2,
        },
        'DELETE' => { 'WHERE' => 1, 'OTHER' => 2, },
    );

    foreach my $idx ( 0 .. $#tokens ) {
        my $token      = uc $tokens[$idx];
        my $next_token = '';
        if ( $idx < $#tokens ) {
            $next_token = uc $tokens[ $idx + 1 ];
        }

        if ( not $statement_type and exists $h{$token} ) {
            $statement_type = $token;
        }

        if ( $token eq '(' ) {
            $parens++;
            $sc[$parens] = '';
        }
        elsif ( $token eq ')' ) {
            $parens--;
            pop @sc;
        }
        elsif ( $token ne "\n" ) {

            if ( exists $h{$statement_type}{$token} ) {
                $last_sub_clause = $token;
                $sc[$parens] ||= $last_sub_clause;
            }
            else {
                $last_sub_clause = 'OTHER';
            }

            if ( $token eq 'CASE' ) {
                push @cases, $token;
            }
            elsif ( @cases and ( $token eq 'WHEN' or $token eq 'ELSE' or $token eq 'END' ) ) {
                if ( $token eq 'END' ) {
                    pop @cases;
                }
            }

        }
        elsif ( $token eq "\n" ) {

            my $last_token      = ( $idx > 0 ) ? uc $tokens[ $idx - 1 ] : '';
            my $next_last_token = ( $idx > 1 ) ? uc $tokens[ $idx - 2 ] : '';

            # Calculate the indents based on parens, case depth, the next token, etc.

            my $indent_parens = $parens;
            if ( $next_token eq ')' ) {
                $indent_parens--;
            }

            my $indent_case = scalar @cases;
            if ( @cases and ( uc $next_token eq 'AND' or uc $next_token eq 'OR' ) ) {
                $indent_case++;
            }

            # if the parens are non-balanced relative to the start
            # then we need to look to the last sub token for indenting. ???

            # if the parens are balanced relative to the start then
            # we need to look to the next token for indenting

            my $sub_used   = '';
            my $sub_token  = '';
            my $indent_sub = 0;
            if ( $next_token =~ m/^~~dml/i or $next_token =~ m/^~~comment/i ) {
                # If ~~dml and previous is /^(UNION|MINUS|EXCEPT|INTERSECT)$/
                # THEN indent same as the previous (UNION|MINUS|EXCEPT|INTERSECT)
                if ( $idx > 1 ) {
                    foreach my $i ( 1 .. $#new_tokens ) {
                        next if ( uc $new_tokens[ -$i ] eq "\n" );
                        next if ( uc $new_tokens[ -$i ] eq '' );
                        next if ( uc $new_tokens[ -$i ] =~ $space_re );
                        next if ( $new_tokens[ -$i ] =~ m/^~~comment/i );
                        if ( uc $new_tokens[ -$i ] =~ m/^(UNION|MINUS|EXCEPT|INTERSECT)$/i ) {
                            $sub_used  = 'last';
                            $sub_token = uc $new_tokens[ -$i ];
                        }
                        last;
                    }
                }
            }
            if ( not $sub_token and $parens > 0 ) {
                $sub_used  = 'last';
                $sub_token = $last_sub_clause;
                if ( $sub_token eq 'WHERE' ) {
                    $sub_token = 'OTHER';
                }
            }

            if ( not $sub_token ) {
                $sub_token = $next_token;
                $sub_used  = 'next';
                if ( !exists $h{$statement_type}{$sub_token} ) {
                    $sub_token = 'OTHER';
                }
            }

            if ( exists $h{$statement_type}{$sub_token} ) {
                $indent_sub = $h{$statement_type}{$sub_token};
            }
            elsif ( exists $h{$statement_type}{'OTHER'} ) {
                $indent_sub = $h{$statement_type}{'OTHER'};
            }

            my $indent = $indenter->to_indent( $indent_sub + $indent_parens + $indent_case );

            push @new_tokens, "\n";
            push @new_tokens, $indent;
        }

        if ( defined $tokens[$idx] and $tokens[$idx] ne "\n" ) {
            push @new_tokens, $tokens[$idx];
        }
    }

    @new_tokens = grep { $_ ne '' } @new_tokens;

    return $self->post_add_indents(@new_tokens);
}

sub post_add_indents {
    my ( $self, @tokens ) = @_;

    return @tokens unless (@tokens);

    my @new_tokens;
    my @line = ();

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];

        push @line, $token;

        if ( $token eq "\n" or $idx == $#tokens ) {
            my $base_indent = '';
            if ( @line and $line[0] =~ $space_re ) {
                $base_indent = $line[0];
            }

            if ( scalar @line < 2 ) {
                # too short to do anything with
                push @new_tokens, @line;
            }
            # window functions with ( partition by, group by, order by, ... )
            elsif ( grep { $_ =~ m/[^ ] +(PARTITION|GROUP|ORDER) +BY/i } join( ' ', @line ) ) {
                push @new_tokens, $Wrapper->format_window_fcn(@line);
            }

            # PIVOT
            elsif ( $line[1] eq 'PIVOT' ) {
                push @new_tokens, $self->format_pivot(@line);
            }
            else {

                if ( $Wrapper->find_first( 'CASE', @line ) ) {
                    @line = $self->format_case(@line);
                }

                if ( $Wrapper->find_first( 'DECODE', @line ) ) {
                    @line = $self->format_decode(@line);
                }

                push @new_tokens, @line;
            }

            @line = ();
        }
    }

    return grep { defined $_ } @new_tokens;
}

sub format_pivot {
    my ( $self, @line ) = @_;

    return @line unless (@line);

    my @new_tokens;
    my $parens  = 0;
    my $did_for = 0;

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

        if ( $idx > 0 ) {

            if ( uc $line[$idx] eq 'FOR' ) {
                $did_for = 1;

                if ( $new_tokens[-1] eq ' ' ) {
                    $new_tokens[-1] = undef;
                }
                my $offset = $parens;
                $offset ||= 1;
                push @new_tokens, "\n", $indenter->add_indents( $base_indent, $offset );
            }
            elsif ( $did_for and ( $line[ $idx - 1 ] eq '(' or $line[ $idx - 1 ] eq ',' ) ) {

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

sub format_case {
    my ( $self, @line ) = @_;

    return @line unless (@line);

    my @new_tokens;
    my $parens      = 0;
    my $cases       = 0;
    my $case_offset = 0;
    my $stmt_offset = 0;

    my %wrap_before = map { $_ => 1 } ( '+', '-', '*', '/', '||' );
    my %indents = map { $_ => 2 } (qw(SELECT WHERE));

    my $base_indent = '';
    if ( @line and $line[0] =~ $space_re ) {
        $base_indent = $line[0];
    }

    foreach my $idx ( 0 .. $#line ) {
        my $token = $line[$idx];
        my $last_token = ( $idx > 0 ) ? $line[ $idx - 1 ] : '';

        if ( uc $token eq '(' ) {
            $parens++;
        }
        elsif ( uc $token eq ')' ) {
            $parens--;
        }
        elsif ( uc $token eq 'CASE' ) {
            # If the CASE is the leading token then do nothing, otherwise
            # indent by base_indent + parens + cases + case_offset
            # If the last token is a math or concatenation operator then
            # indent before the last token (unless we've already indented before the operator).

            if ( exists $indents{ uc $line[0] } ) {
                $stmt_offset = $indents{ uc $line[0] };
            }
            elsif ( $line[0] =~ $space_re and exists $indents{ uc $line[1] } ) {
                $stmt_offset = $indents{ uc $line[1] };
            }

            if ( $idx == 0 or ( $idx == 1 and $last_token =~ $space_re ) ) {
                # Do nothing
            }
            elsif ( $idx > 0 and exists $wrap_before{ $new_tokens[-1] } ) {
                if ( $idx > 1 and $new_tokens[-2] =~ $space_re ) {
                    # Dont re-wrap...
                }
                else {
                    $case_offset = 1;
                    my $temp = $new_tokens[-1];
                    $new_tokens[-1] = undef;
                    push @new_tokens, "\n",
                        $indenter->add_indents( $base_indent, $parens + $cases + $case_offset + $stmt_offset );
                    push @new_tokens, $temp;
                }
            }
            elsif ( $last_token eq '(' ) {
                push @new_tokens, "\n",
                    $indenter->add_indents( $base_indent, $parens + $cases + $case_offset + $stmt_offset );
            }

            $cases++;
        }
        elsif ( uc $token eq 'END' ) {
            if ($cases) {
                push @new_tokens, "\n",
                    $indenter->add_indents( $base_indent, $parens + $cases + $case_offset + $stmt_offset );
                $cases--;
            }
        }
        elsif ( uc $token eq 'WHEN' ) {
            if ($cases) {
                push @new_tokens, "\n",
                    $indenter->add_indents( $base_indent, $parens + $cases + $case_offset + $stmt_offset );
            }
        }
        elsif ( uc $token eq 'ELSE' ) {
            if ($cases) {
                push @new_tokens, "\n",
                    $indenter->add_indents( $base_indent, $parens + $cases + $case_offset + $stmt_offset );
            }
        }

        push @new_tokens, $token;
    }

    return grep { defined $_ } @new_tokens;
}

sub format_decode {
    my ( $self, @line ) = @_;

    return @line unless (@line);

    my @new_tokens;
    my $parens     = 0;
    my @dec_parens = (0);
    my @dec_commas = (0);
    my $decodes    = 0;

    my %wrap_before = map { $_ => 1 } ( '+', '-', '*', '/', '||' );

    my $base_indent = '';
    if ( @line and $line[0] =~ $space_re ) {
        $base_indent = $line[0];
    }

    foreach my $idx ( 0 .. $#line ) {
        my $token = $line[$idx];
        my $last_token = ( $idx > 0 ) ? $line[ $idx - 1 ] : '';

        if ( uc $token eq 'DECODE' ) {

            if ( $idx == 0 or ( $idx == 1 and $last_token =~ $space_re ) ) {
                # Do nothing
            }
            elsif ( $idx > 0 and exists $wrap_before{ $new_tokens[-1] } ) {
                if ( $idx > 1 and $new_tokens[-2] =~ $space_re ) {
                    # Dont re-wrap...
                }
                else {
                    my $temp = $new_tokens[-1];
                    $new_tokens[-1] = undef;
                    push @new_tokens, "\n", $indenter->add_indents( $base_indent, $parens + $decodes + 1 );
                    push @new_tokens, $temp;
                }
            }

            $decodes++;
            $dec_parens[$decodes] = 0;
            $dec_commas[$decodes] = 0;

        }
        elsif ( $token eq '(' ) {
            $parens++;
            if ($decodes) {
                $dec_parens[$decodes]++;
            }
        }
        elsif ( $token eq ')' ) {
            $parens--;
            if ($decodes) {
                $dec_parens[$decodes]--;
                if ( $dec_parens[$decodes] == 0 ) {
                    $decodes--;
                    my $next_token = ( $idx < $#line ) ? uc $line[ $idx + 1 ] : '';

                    # Do we wrap at the end of the decode? Usually
                    # yes, but not if the decode is at the "end of the
                    # line" where end of line == [AS] alias [,]

                    if (   uc $next_token eq 'AS'
                        or $next_token eq ')'
                        or $next_token eq ','
                        or $#line - $idx == 1
                        or $#line - $idx == 2 and $line[-1] eq ',' )
                    {
                        # Do not wrap
                    }
                    else {
                        push @new_tokens, $token;
                        my $offset = $parens;
                        $offset ||= 1;
                        push @new_tokens, "\n", $indenter->add_indents( $base_indent, $offset );
                        $token = undef;
                    }

                }
            }
        }
        elsif ( $token eq ',' ) {
            if ($decodes) {
                $dec_commas[$decodes]++;

                my $offset = $parens + $decodes;
                $offset ||= 1;

                if ( $dec_commas[$decodes] % 2 ) {
                    push @new_tokens, $token;
                    push @new_tokens, "\n", $indenter->add_indents( $base_indent, $offset );
                    $token = undef;
                }
            }
        }

        if ( defined $token ) {
            push @new_tokens, $token;
        }

    }

    return grep { defined $_ } @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;

