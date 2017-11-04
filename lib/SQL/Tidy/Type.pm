package SQL::Tidy::Type;
use strict;
use warnings;

=head1 NAME

SQL::Tidy::Type

=head1 SYNOPSIS

Parent class of types of things to be tagged, untaggeg, formatted (DML,
DDL, PL, etc.)

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

    return $self;
}

=item tag ( tokens )

Replaces blocks of the language type ( DDL, DML, PL, etc.)
with a tag and stores the original block in a reference hash.

Returns a hash-ref of the tags and the modified list of tokens.

=cut

sub tag {
    my ( $self, @tokens ) = @_;
    my %blocks;

    return ( \%blocks, @tokens );
}

=item untag ( blocks, tokens )

Takes the hash of block tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag {
    my ( $self, $blocks, @tokens ) = @_;
    return @tokens;
}

sub format {
    my ( $self, $comments, $blocks ) = @_;

    if ( $blocks and ref($blocks) eq 'HASH' ) {
        foreach my $key ( keys %{$blocks} ) {
            my @ary = @{ $blocks->{$key} };

            @ary = $self->unquote_identifiers(@ary);
            @ary = $self->capitalize_keywords(@ary);
            @ary = $self->add_vspace( $comments, @ary );
            @ary = $self->add_indents(@ary);

            $blocks->{$key} = \@ary;
        }
    }
    return $blocks;
}

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    return @tokens;
}

sub _capitalize_keywords {
    my ( $self, $keywords, @tokens ) = @_;
    my @new_tokens;

    foreach my $token (@tokens) {

        if ( exists $keywords->{ uc $token } ) {
            push @new_tokens, $keywords->{ uc $token }{word};
        }
        elsif ( $token =~ m/^[A-Za-z0-9_\#\$\.]+$/ ) {
            push @new_tokens, lc $token;
        }
        else {
            push @new_tokens, $token;
        }
    }

    return @new_tokens;
}

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;
    return @tokens;
}

sub _unquote_identifiers {
    my ( $self, $keywords, $pct_attribs, $stu_re, $case_folding, @tokens ) = @_;
    my @new_tokens;

    #    my $stu_re   = $Dialect->safe_ident_re();

    if ( $case_folding eq 'upper' or $case_folding eq 'lower' ) {

        foreach my $token (@tokens) {
            if ( $token =~ m/^".+"$/ ) {
                # Something quoted this way comes...
                if ( $token =~ m/^"[A-Za-z0-9_\#\$]+"$/ ) {

                    my $tmp = $token;
                    $tmp =~ s/^"//;
                    $tmp =~ s/"$//;

                    if ( not exists $keywords->{ uc $tmp } ) {
                        $token = lc $tmp;
                    }
                }
            }
            elsif ( not exists $keywords->{ uc $token } ) {
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
            my $tmp = $token;

            # Attempt to deal with the '#' or '$' being at the beginning/
            #   end of the identifier. TODO: can the tokenizer be fixed to deal with this?
            if ( $next_token and $next_token =~ m/^[a-z0-9_]/i and not exists $keywords->{ uc $next_token } ) {
                $tokens[ $idx + 1 ] = undef;
                $tmp .= $next_token;
            }

            if ( @new_tokens and $new_tokens[-1] =~ m/^[a-z]/i and not exists $keywords->{ uc $new_tokens[-1] } ) {
                $new_tokens[-1] .= $tmp;
            }
            else {
                push @new_tokens, $tmp;
            }

        }

        elsif ( $token eq '%' and $idx < $#tokens ) {

            if (@new_tokens) {
                if ( exists $pct_attribs->{ uc $next_token } ) {
                    $new_tokens[-1] .= $token . $tokens[ $idx + 1 ];
                    $tokens[ $idx + 1 ] = undef;
                }
                else {
                    push @new_tokens, $token;
                }
            }
            else {
                push @new_tokens, $token;
            }
        }

        else {
            push @new_tokens, $token;
        }
    }
    return @new_tokens;
}

sub add_vspace {
    my ( $self, $comments, @tokens ) = @_;
    return @tokens;
}

sub add_indents {
    my ( $self, @tokens ) = @_;
    return @tokens;
}

1;
