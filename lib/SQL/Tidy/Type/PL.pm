package SQL::Tidy::Type::PL;
use base 'SQL::Tidy::Type';
use strict;
use warnings;

use SQL::Tidy::Dialect;
use SQL::Tidy::Indent;
use SQL::Tidy::Wrap;

=head1 NAME

SQL::Tidy::Type::PL

=head1 SYNOPSIS

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

Replaces PL/SQL or PL/PgSQL or whatever procedural blocks
with a tag and stores the original PL in a reference hash.

Returns a hash-ref of the PL tags and the modified list of tokens.

=cut

sub tag {
    my ( $self, @tokens ) = @_;

    # ASSERTIONS:
    #   - The DML has already been tagged and bagged
    #   - The DDL has not been tagged (and in fact requires the PL to be tagged first)
    #   - ThE PL may be stand-alone or may be part of a CREATE/REPLACE statement
    #   - No "spaces" tokens have been added yet

    # Nota bene: The initial is very Oracle specific. It remains to be
    #   seen if that can be extended for Postgres, etc. or if each
    #   dialect gets a dialect specific tagger.
    #
    # Oracle:
    #   CREATE ....
    #   AS
    #   ...
    #   END ;
    #   /

    # Pg:
    #   CREATE ....
    #   AS $TAG$
    #   ...
    #   END ;
    #   $TAG$ [language language_name ]

    my %pl;

    my $pl_key;
    my @new_tokens;
    my $parens = 0;

    my $is_ddl     = 0;
    my $pl_type    = '';
    my $ddl_header = '';
    my $ddl_type   = '';
    my $pl_terminator;

    foreach my $idx ( 0 .. $#tokens ) {

        next unless ( defined $tokens[$idx] );

        my $token      = uc $tokens[$idx];
        my $last_token = '';
        if ( $idx > 0 and defined $tokens[ $idx - 1 ] ) {
            $last_token = uc $tokens[ $idx - 1 ];
        }

        if ( $token eq '(' ) {
            $parens++;
        }
        elsif ( $token eq ')' ) {
            $parens--;
        }

        if ( $token eq 'CREATE' ) {
            if ($ddl_type) {
                # This would be a problem as either the tagging is
                # deficient or the script is missing something.
            }
            $is_ddl     = 1;
            $ddl_header = 'CREATE';
        }
        elsif ( $ddl_header eq 'CREATE' and $token =~ m/^(FUNCTION|PACKAGE|PROCEDURE|TRIGGER)$/ ) {
            $ddl_header = $token;
            $ddl_type   = $token;
        }
        elsif ( $ddl_header and $token eq ';' ) {
            $ddl_header = '';    # Something like a Pg trigger?
        }

        if ($pl_key) {

            # Very Oracle:
            if ( $token eq '/' and $last_token eq ';' ) {
                $pl_key   = '';
                $ddl_type = '';
            }
            # PostgreSQL:
            elsif ( $pl_terminator and $token eq $pl_terminator and $last_token eq ';' ) {
                $pl_key        = '';
                $ddl_type      = '';
                $pl_terminator = undef;
            }
        }
        elsif ( $ddl_header and $ddl_type and $ddl_type ne 'TRIGGER' and $parens == 0 and $token =~ m/^(IS|AS)$/i ) {

            $ddl_header = '';
            $pl_key = '~~pl_' . sprintf( "%04d", $idx );
            push @new_tokens, $tokens[$idx];
            push @new_tokens, $pl_key;
            $tokens[$idx] = undef;    # Don't push it twice

            # if the next token starts/ends with $ then it's a PL/pgSQL block
            if ( $idx < $#tokens ) {
                if ( $tokens[ $idx + 1 ] =~ m/\$.*\$/ ) {
                    $pl_terminator = $tokens[ $idx + 1 ];
                }
            }

        }
        elsif ( $ddl_header and $ddl_type eq 'TRIGGER' and ( $token eq 'BEGIN' or $token eq 'DECLARE' ) ) {
            $ddl_header = '';
            $pl_key = '~~pl_' . sprintf( "%04d", $idx );
            push @new_tokens, $pl_key;
        }
        elsif ( $parens == 0 and $token =~ m/^(BEGIN|DECLARE)$/i ) {
            $ddl_header = '';
            $pl_key = '~~pl_' . sprintf( "%04d", $idx );
            push @new_tokens, $pl_key;
        }

        if ( defined $tokens[$idx] ) {
            if ($pl_key) {
                push @{ $pl{$pl_key} }, $tokens[$idx];
            }
            else {
                push @new_tokens, $tokens[$idx];
            }
        }

=pod

Oracle:

CREATE [OR REPLACE] TRIGGER trigger_name

BEGIN

    ...

END [label] ;
/

------------------------------------------------------------------------

PostgreSQL

CREATE TRIGGER trigger_name

EXECUTE PROCEDURE ... ; -- No real PL; is contained in trigger function

------------------------------------------------------------------------

Oracle

CREATE OR REPLACE {FUNCTION|PROCEDURE} ... {IS|AS} -- beware of parens (may be an IS/AS inside signature?)

    ...

END [label] ;
/

------------------------------------

CREATE [OR REPLACE] PACKAGE ... AS
...

END [label] ;
/

------------------------------------

CREATE [OR REPLACE] PACKAGE BODY ... AS

END [label] ;
/

Note: Oracle functions/procedures can nest. '/' is for the entire block, not any sub-blocks

------------------------------------------------------------------------

PostgreSQL

CREATE FUNCTION ... AS <tag> ... <tag> [LANGUAGE lang] ;





=cut

    }

    return ( \%pl, grep { $_ ne '' } @new_tokens );
}

=item untag ( PL, tokens )

Takes the hash of PL tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag {
    my ( $self, $pls, @tokens ) = @_;

    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~pl_/ ) {
            push @new_tokens, "\n";
            push @new_tokens, @{ $pls->{$token} };
            push @new_tokens, "\n";
        }
        else {
            push @new_tokens, $token;
        }
    }

    return @new_tokens;
}

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    my %keywords = $Dialect->pl_keywords();
    return $self->_capitalize_keywords( \%keywords, @tokens );
}

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;

    my %keywords    = $Dialect->pl_keywords();
    my $stu_re      = $Dialect->safe_ident_re();
    my %pct_attribs = $Dialect->pct_attribs();

    return $self->_unquote_identifiers( \%keywords, \%pct_attribs, $stu_re, $case_folding, @tokens );
}

sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    my @new_tokens;
    my @block_stack;
    my $in_proc_sig = 0;

    # TODO: Need to deal with [sub?] procedure prototypes/headers that
    # have no arguments "PROCEDURE foo IS [some_id table.column%type [:= value]]"

    foreach my $idx ( 0 .. $#tokens ) {
        my $token       = uc $tokens[$idx];
        my $line_before = 0;
        my $line_after  = 0;

        # Force function/procedure signatures to line-wrap
        if ( $token eq 'FUNCTION' or $token eq 'PROCEDURE' ) {
            $in_proc_sig = 1;
        }
        elsif ($in_proc_sig) {
            if ( $token eq '(' ) {
                $line_after = 1;
            }
            elsif ( $token eq ',' ) {
                $line_after = 1;
            }
            elsif ( $token eq ';' ) {
                $in_proc_sig = 0;
                $line_after  = 1;
            }
            elsif ( $token eq 'AS' ) {
                $in_proc_sig = 0;
                $line_before = 1;
                $line_after  = 1;
            }
            elsif ( $token eq 'IS' ) {
                $in_proc_sig = 0;
                $line_before = 1;
                $line_after  = 1;
            }
        }

        if ( $token eq 'DECLARE' ) {
            $line_before = 1;
            $line_after  = 1;
        }
        elsif ( $token eq 'BEGIN' ) {
            push @block_stack, $token;
            $line_before = 2;
            $line_after  = 1;
        }
        elsif ( $token eq 'EXCEPTION' or $token eq 'EXCEPTIONS' ) {
            # But only if it is the beginning of an exception block
            # instead of a custom exception definition or something
            my $next_token = ( $idx < $#tokens ) ? uc $tokens[ $idx + 1 ] : '';
            if ( $next_token ne ';' ) {
                if ( $block_stack[-1] eq 'BEGIN' ) {
                    $block_stack[-1] = 'EXCEPTION';
                }
                $line_before = 2;
            }
        }
        elsif ( $token eq 'RETURN' ) {
            $line_before = 1;
        }

        # [procedure|function] <name> IS

        elsif ( $token eq 'IF' ) {

            # Ensure that this is the beginning of an IF block, not the end of one
            foreach my $i ( 1 .. $#new_tokens ) {
                my $lastok = $new_tokens[ -$i ];

                next if ( $lastok =~ $space_re );
                next if ( $lastok eq "\n" );
                if ( $lastok ne 'END' ) {
                    push @block_stack, $token;
                    $line_before = 2;
                }
                last;
            }
        }
        elsif ( $token eq 'CASE' ) {
            push @block_stack, $token;
            $line_before = 2;
        }
        elsif ( $token eq 'LOOP' ) {
            # Ensure that this is the beginning of a LOOP block, not the end of one
            foreach my $i ( 1 .. $#new_tokens ) {
                my $lastok = $new_tokens[ -$i ];

                next if ( $lastok =~ $space_re );
                next if ( $lastok eq "\n" );
                if ( $lastok ne 'END' ) {
                    push @block_stack, $token;
                    $line_after = 1;
                }
                last;
            }
        }
        elsif ( $token =~ /^~~dml/i ) {
            # TODO: single line only if the preceeding is 'IN ('
            $line_before = 2;
            #$line_after = 2;

            foreach my $i ( 1 .. $#new_tokens ) {
                my $lastok = $new_tokens[ -$i ];

                next if ( $lastok =~ $space_re );
                next if ( $lastok eq "\n" );
                if ( $lastok eq '(' or $lastok eq 'IS' or $lastok eq 'AS' ) {
                    $line_before = 1;
                }
                last;
            }
        }
        elsif ( $token =~ m/^~~comment/i ) {
            # TODO: If the comment is after an "END .., ;", and there
            #   is a preceeding line-break then ensure the break is
            #   double spaced.

            $line_before = $comments->{ lc $token }{newline_before};
            $line_after  = $comments->{ lc $token }{newline_after};
        }
        elsif ( $token eq 'END' ) {
            # IF    -- END IF ;
            # LOOP  -- END LOOP [label] ;
            # CASE  -- END ;
            # BEGIN -- END [ pl_name ] ;

            $line_before = 1;
            if (@block_stack) {

                if ( $block_stack[-1] eq 'IF' ) {
                    $line_before++;
                }
                pop @block_stack;
            }

            # TODO: maybe double space after an END as a general
            #   principle and only single space on stacked ENDs
        }
        elsif ( $token eq 'THEN' ) {
            if ( $block_stack[-1] eq 'IF' ) {
                $line_after = 1;
            }
            elsif ( $block_stack[-1] eq 'EXCEPTION' ) {
                $line_after = 1;
            }
        }
        elsif ( $token eq 'ELSIF' ) {
            $line_before = 2;
        }
        elsif ( $token eq 'ELSE' ) {
            # ELSE behavior is context sensitive based on whether it is
            #   part of an IF block or a CASE block.
            if ( $block_stack[-1] eq 'IF' ) {
                $line_before = 2;
                $line_after  = 2;
            }
            elsif ( $block_stack[-1] eq 'CASE' ) {
                $line_before = 1;
            }
        }
        elsif ( $token eq 'WHEN' ) {
            # WHEN behavior is context sensitive based on whether it is
            #   part of a LOOP, CASE, or EXCEPTION block.

            if ( $block_stack[-1] eq 'CASE' ) {
                $line_before = 1;
            }
            elsif ( $block_stack[-1] eq 'EXCEPTION' ) {
                $line_before = 1;
            }
        }
        elsif ( $token eq ',' ) {
            if ( $idx < $#tokens and $tokens[ $idx + 1 ] =~ /^~~comment/i ) {
                $line_after = $comments->{ lc $token }{newline_before} || 0;
            }
        }
        elsif ( $token eq ';' ) {
            if ( $tokens[ $idx - 1 ] =~ /^~~dml/i ) {
                $line_after = 2;
            }
            elsif ( $idx < $#tokens and $tokens[ $idx + 1 ] =~ /^~~comment/i ) {
                $line_after = $comments->{ lc $token }{newline_before} || 0;
            }
            else {
                $line_after = 1;
                foreach my $i ( 1 .. $#new_tokens ) {
                    my $lastok = $new_tokens[ -$i ];

                    if ( $lastok eq 'END' ) {
                        $line_after = 2;
                    }
                    elsif ( $lastok eq "\n" ) {
                        last;
                    }
                }
            }
        }

        if ( 0 == $idx ) {
            $line_before = 0;
        }
        if ( $#tokens == $idx ) {
            $line_after = 0;
        }

        # trim trailing spaces
        if ( $token eq "\n" or $line_before ) {
            if ( $new_tokens[-1] =~ $space_re ) {
                $new_tokens[-1] = '';
            }
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

    return grep { $_ ne '' } @new_tokens;
}

sub add_indents {
    my ( $self, @tokens ) = @_;
    my @new_tokens;
    my $parens       = 0;
    my $in_proc_sig  = 0;
    my $in_exception = 0;
    my $cases        = 0;
    my @eb_stack     = ();
    my $eb_depth     = 0;

    # TODO: If we are dealing with a cursor definition, do we want to
    #   indent the SQL statement?

    my %h = (

        'FUNCTION'  => 1,
        'PROCEDURE' => 1,
        'IS'        => 1,
        'AS'        => 1,
        'DECLARE'   => 1,
        'BEGIN'     => 1,
        'LOOP'      => 1,
        'IF'        => 1,
        'ELSIF'     => 1,
        'ELSE'      => 1,
        'END'       => 1,
        'EXCEPTION' => 1,
        'OTHER'     => 2
    );

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = uc $tokens[$idx];
        next unless ( defined $token );

        my $next_token = ( $idx < $#tokens ) ? uc $tokens[ $idx + 1 ] : '';
        my $last_token = ( $idx > 0 )        ? uc $tokens[ $idx - 1 ] : '';

        # On new lines, the indent needs to know next token in order to
        # have a clue as to how much to indent.
        my $needs_indent = 0;
        if ( $token eq "\n" ) {
            $needs_indent = 1;

            if (   $next_token eq 'FUNCTION'
                or $next_token eq 'PROCEDURE' )
            {
                $in_proc_sig = 1;
                $eb_depth++;
                $eb_stack[$eb_depth] = $next_token;

            }
            elsif ( $next_token eq 'IF' ) {
                $eb_depth++;
                $eb_stack[$eb_depth] = $next_token;
            }
            elsif ( $next_token eq 'CASE' ) {
                $cases++;
                $eb_depth++;
                $eb_stack[$eb_depth] = $next_token;
            }
            elsif ( $next_token eq 'BEGIN' ) {
                if ( @eb_stack and $eb_stack[-1] and ( $eb_stack[-1] eq 'FUNCTION' or $eb_stack[-1] eq 'PROCEDURE' ) ) {
                    $eb_stack[-1] = $next_token;
                }
                elsif ( $eb_depth > -1 ) {
                    $eb_depth++;
                    $eb_stack[$eb_depth] = $next_token;
                }
            }
            elsif ( $next_token eq 'EXCEPTION' ) {
                my $third_token = ( $idx + 1 < $#tokens ) ? uc $tokens[ $idx + 2 ] : '';
                if ( $third_token ne ';' ) {
                    $in_exception = 1;
                    if ( $eb_depth > -1 ) {
                        $eb_stack[$eb_depth] = $next_token;
                    }
                }
            }
        }
        elsif ( $idx == 0 ) {
            # Note: only do this if it is the first token as the
            # '$token eq "\n"' check should get it otherwise.

            if ( $token !~ m/\$.*\$/ ) {
                # Not the beginning of a Pg PL
                $needs_indent = 1;
            }
            if ( $token eq 'FUNCTION' or $token eq 'PROCEDURE' ) {
                $in_proc_sig = 1;
                $eb_depth++;
                $eb_stack[$eb_depth] = $token;
            }
        }

        ################################################################
        if ($needs_indent) {
            my $offset = 0;

            if ( $token eq "\n" ) {

                if ( $in_exception
                    and ( $next_token ne 'EXCEPTION' and $next_token ne 'WHEN' and $next_token ne 'END' ) )
                {
                    $offset += 2;
                }
                elsif ( $next_token eq 'CASE' ) {
                }
                elsif ( $cases and $eb_stack[-1] and $next_token ne 'END' ) {
                    $offset++;
                }
                elsif ( exists $h{$next_token} or $in_proc_sig ) {
                    # Nothing
                }
                else {
                    $offset++;
                }

                my $indent = $indenter->to_indent( $eb_depth + $parens + $offset );
                push @new_tokens, "\n", $indent;
            }
            else {

                if (    $idx == 0
                    and $token ne 'FUNCTION'
                    and $token ne 'PROCEDURE'
                    and $token ne 'BEGIN'
                    and $token ne 'DECLARE' )
                {
                    $offset++;
                }

                my $indent = $indenter->to_indent( $eb_depth + $parens + $offset );
                push @new_tokens, $indent, $tokens[$idx];
            }
        }
        elsif ( defined $tokens[$idx] ) {
            push @new_tokens, $tokens[$idx];
        }

        ################################################################
        if ( $next_token eq 'END' ) {
            pop @eb_stack;
            $eb_depth--;
            $in_exception = 0;
            if ($cases) {
                $cases--;
            }
        }

        if ( $token eq '(' ) {
            $parens++;
        }
        elsif ( $token eq ')' ) {
            $parens--;
        }
        elsif ( $token eq ';' ) {
            if ($in_proc_sig) {
                # 'tis merely a function/procedure prototype
                $in_proc_sig = 0;
                pop @eb_stack;
                $eb_depth--;
            }
        }
        elsif ( $token eq 'IS' ) {
            if ($in_proc_sig) {
                $in_proc_sig = 0;
            }
        }
        elsif ( $token eq 'AS' ) {
            if ( $in_proc_sig and $parens == 0 ) {
                $in_proc_sig = 0;
            }
        }
        elsif ( $token eq 'LOOP' ) {
            if ( $next_token eq "\n" ) {
                # TODO: or next token is a comment and the one after that is the "\n"
                $eb_depth++;
                $eb_stack[$eb_depth] = $token;
            }
        }
    }

    return $self->post_add_indents(@new_tokens);
}

sub post_add_indents {
    my ( $self, @tokens ) = @_;

    return @tokens unless (@tokens);

    my @new_tokens = $self->format_cursor(@tokens);

    return grep { defined $_ } @new_tokens;
}

sub format_cursor {
    my ( $self, @tokens ) = @_;

    return @tokens unless (@tokens);
    return @tokens unless ( $Wrapper->find_first( 'CURSOR', @tokens ) );

    my @new_tokens;
    my $base_indent = '';
    my $commas      = 0;
    my $parens      = 0;
    my $in_cursor   = 0;
    my @cursor      = ();

    foreach my $idx ( 0 .. $#tokens ) {
        my $token      = uc $tokens[$idx];
        my $last_token = ( $idx > 0 and defined $tokens[ $idx - 1 ] ) ? uc $tokens[ $idx - 1 ] : '';
        my $next_token = ( $idx < $#tokens ) ? uc $tokens[ $idx + 1 ] : '';

        if ( $token eq 'CURSOR' and ( $last_token eq "\n" or $last_token =~ $space_re ) ) {
            $in_cursor = 1;
            @cursor    = $tokens[$idx];
            $parens    = 0;
            $commas    = 0;
            if ( $last_token =~ $space_re ) {
                $base_indent = $last_token;
            }
            else {
                $base_indent = '';
            }
        }
        elsif ($in_cursor) {

            push @cursor, $tokens[$idx];
            if ( $token eq '(' ) {
                $parens++;
            }
            elsif ( $token eq ')' ) {
                $parens--;
            }
            elsif ( $token eq ',' ) {
                $commas++;
            }
            elsif ( $token eq ';' ) {

                $in_cursor = 0;

                foreach my $t (@cursor) {
                    # Ensure that an extra indent is in front of the DML statement
                    if ( $t =~ m/^~~dml/i ) {

                        if ( $new_tokens[-1] eq "\n" ) {
                            push @new_tokens, $indenter->add_indents( $base_indent, 1 );
                        }
                        elsif ( $new_tokens[-1] =~ $space_re ) {
                            $new_tokens[-1] = $indenter->add_indents( $new_tokens[-1], 1 );
                        }
                    }

                    push @new_tokens, $t;

                    # If there are two or more arguments to the cursor then wrap on commas and open parens ( two indents )
                    if ( $commas and ( $t eq '(' or $t eq ',' ) ) {
                        push @new_tokens, "\n", $indenter->add_indents( $base_indent, 2 );
                    }
                }
            }
        }
        else {
            push @new_tokens, $tokens[$idx];
        }
    }

    return grep { defined $_ } @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
