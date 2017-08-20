package SQL::Tidy::DML;
use strict;
use warnings;

use Data::Dumper;

=head1 NAME

SQL::Tidy::DML

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

=item tag_dml ( tokens )

Replaces SQL query statements (DML blocks as opposed to PL-code, etc.)
with a tag and stores the original DML in a reference hash.

We do this because it appears that SQL statements need different rules
for formatting, etc.

Returns a hash-ref of the DML tags and the modified list of tokens.

=cut

sub tag_dml {
    my ( $self, @tokens ) = @_;

    my %dml;
    my $dml_key;
    my @new_tokens;
    my $is_grant = 0;
    my $parens   = 0;

    foreach my $idx ( 0 .. $#tokens ) {

        my $token = $tokens[$idx];

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
        elsif ( !$is_grant and $token =~ m/^(WITH|SELECT|INSERT|UPDATE|DELETE|MERGE)$/i ) {
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
        if ( $token eq 'GRANT' or $token eq 'REVOKE' ) {
            $is_grant = 1;
        }
        elsif ( $token eq ';' ) {
            if ($is_grant) {
                $is_grant = 0;
            }
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

sub untag_dml {
    my ( $self, $dmls, @tokens ) = @_;
    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~dml_/ ) {
            my @ary = @{ $dmls->{$token} };

            #($recurse) = grep { $_ =~ m/^~~dml_/ } @ary;

            # Determine the indent to add to each line base on the
            # indent of the dml tag
            my $indent = (@new_tokens) ? $new_tokens[-1] : '';
            if ( $indent =~ $space_re ) {
                # Bump the indent of each indentation token in the dml
                # block (excepting the first of course)
                foreach my $dml_idx ( 0 .. $#ary ) {
                    my $dml_tok = $ary[$dml_idx];

                    if ( $dml_idx > 0 and $ary[ $dml_idx - 1 ] eq "\n" and $dml_tok =~ $space_re ) {
                        $dml_tok = $indent . $dml_tok;
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
        @new_tokens = $self->untag_dml( $dmls, @new_tokens );
    }

    return @new_tokens;
}

=item format_dml ()


=cut

sub format_dml {
    my ( $self, $comments, $dmls ) = @_;

    if ( $dmls and ref($dmls) eq 'HASH' ) {
        foreach my $key ( keys %{$dmls} ) {
            my @ary = @{ $dmls->{$key} };

            #@ary = $self->unquote_identifiers(@ary);
            @ary = $self->capitalize_keywords(@ary);
            @ary = $self->add_vspace( $comments, @ary );
            @ary = $self->add_indents(@ary);

            $dmls->{$key} = \@ary;
        }
    }
    return $dmls;
}

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    my @new_tokens;
    my %keywords = $Dialect->dml_keywords();
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
    my @new_tokens;

    my %keywords = $Dialect->dml_keywords();
    my $stu_re   = $Dialect->safe_ident_re();

    if ( $case_folding eq 'upper' or $case_folding eq 'lower' ) {

        foreach my $token (@tokens) {
            if ( $token =~ m/^"[A-Za-z0-9_\#\$]+"$/ ) {

                # Something quoted this way comes...
                my $tmp = $token;
                $tmp =~ s/^"//;
                $tmp =~ s/"$//;

                if ( not exists $keywords{ uc $tmp } ) {
                    $token = lc $tmp;
                }
            }
            elsif ( not exists $keywords{ uc $token } ) {
                $token = lc $token;
            }
        }
    }

    # Join identifiers "token.token" into token
    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        next unless ( defined $token );
        my $next_token = ( $idx < $#tokens ) ? $tokens[ $idx + 1 ] : '';

        # If the token is a dot '.' then join it and the next token to
        # the previous token. This should account for instances of
        # schema.table, table.column, schema.table.column, etc.
        if ( $token eq '.' and $next_token and $next_token =~ m/^["a-z]/i ) {
            $tokens[ $idx + 1 ] = undef;
            $new_tokens[-1] .= '.' . $next_token;
        }
        elsif ( $token =~ m/^["a-z].+\.$/i and $next_token and $next_token =~ m/^["a-z]/i ) {
            $tokens[ $idx + 1 ] = undef;
            push @new_tokens, $token . $next_token;
        }
        # For Oracle DB-links
        elsif ( $token =~ m/^[@]["a-z]/i ) {
            $new_tokens[-1] .= $token;
        }

        # Oracle: for '#' and '$' in identifiers
        elsif ( $token eq '#' or $token eq '$' ) {
            if ( $new_tokens[-1] =~ m/^[a-z]/i ) {
                $new_tokens[-1] .= $token;
            }
            if ( $next_token and $next_token =~ m/^[a-z0-9_]/i ) {
                $tokens[ $idx + 1 ] = undef;
                $new_tokens[-1] .= $next_token;
            }
        }

        else {
            push @new_tokens, $token;
        }
    }
    return @new_tokens;
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
        }
        elsif ( $token eq 'AND' ) {
            $line_before = 1;
            # back-track new tokens looking for 'BETWEEN' in the current line
            if ( scalar @new_tokens > 2 and uc $new_tokens[-2] eq 'BETWEEN' ) {
                $line_before = 0;
            }
        }
        # CASE ???
        elsif ( $token eq 'CASE' ) {
            push @cases, $token;
            $line_before = 1;
        }
        elsif ( @cases and ( $token eq 'WHEN' or $token eq 'ELSE' or $token eq 'END' ) ) {
            $line_before = 1;
            if ( $token eq 'END' ) {
                pop @cases;
            }
        }
        # TODO: vspace for other...
        else {

            my $test = $token;
            if ( $test =~ m/^(RIGHT|LEFT|CROSS|FULL|NATURAL|INNER|OUTER|JOIN)$/i ) {
                $test = 'JOIN';
            }

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

        ################################################################
        #if (0 == $idx) {
        #    $line_before = 0
        #}
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
            'INTO' => 1,
            'FROM' => 1,
            'JOIN' => 1,

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
        'DELETE' => { 'WHERE' => 1, },
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

            # Calculate the indents based on parens, case depth, the next token, etc.

            my $indent_parens = $parens;
            if ( $next_token eq ')' ) {
                $indent_parens--;
            }

            my $indent_case = scalar @cases;

            # if the parens are non-balanced relative to the start
            # then we need to look to the last sub token for indenting. ???

            # if the parens are balanced relative to the start then
            # we need to look to the next token for indenting

            my $sub_used   = '';
            my $sub_token  = '';
            my $indent_sub = 0;
            if ( $parens > 0 ) {
                $sub_used  = 'last';
                $sub_token = $last_sub_clause;
                if ( $sub_token eq 'WHERE' ) {
                    $sub_token = 'OTHER';
                }
            }
            else {
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
            #push @new_tokens, "-- " . join (', ', $indent_sub , $indent_parens , $indent_case, length($indent) );
            push @new_tokens, $indent;
        }

        # TODO:

        if ( defined $tokens[$idx] and $tokens[$idx] ne "\n" ) {
            push @new_tokens, $tokens[$idx];
        }

        # TODO: post pushing adjustments?

    }

    @new_tokens = grep { $_ ne '' } @new_tokens;

    return @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;

