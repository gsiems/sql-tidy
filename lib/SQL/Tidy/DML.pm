package SQL::Tidy::DML;
use strict;
use warnings;

=head1 NAME

SQL::Tidy::DML

=head1 SYNOPSIS

Tag and untag blocks of SQL queries (DML)

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

    foreach my $key ( keys %{$args} ) {
        unless ( exists $args->{$key} ) {
            $self->{$_} = $args->{$_};
        }
    }

    return $self;
}

=item tag_DML ( tokens )

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

            if ($dml_key) {
                push @{ $dml{$dml_key} }, $token;
            }
        }
        elsif ( !$is_grant and $token =~ m/^(WITH|SELECT|INSERT|UPDATE|DELETE|MERGE)$/ ) {
            # If the token is (WITH|SELECT|INSERT|UPDATE|DELETE|MERGE),
            # and we aren't already in a statement then it looks like
            # we are starting a statement.
            if (@new_tokens) {
                foreach my $j ( 1 .. $#new_tokens ) {
                    next if ( $new_tokens[ -$j ] eq "\n" );
                    next if ( $new_tokens[ -$j ] =~ /^\s+$/ );
                    next if ( $new_tokens[ -$j ] =~ /^~~comment/ );
                    next if ( $new_tokens[ -$j ] eq "/" );
                    last if ( uc $new_tokens[ -$j ] eq 'GRANT' );
                    last if ( uc $new_tokens[ -$j ] eq 'REVOKE' );

                    $dml_key = '~~dml_' . sprintf( "%06d", $idx );
                    push @{ $dml{$dml_key} }, $token;
                    push @new_tokens, $dml_key;

                    $parens = 0;

                    last;
                }
            }
            else {
                $dml_key = '~~dml_' . sprintf( "%06d", $idx );
                push @{ $dml{$dml_key} }, $token;
                push @new_tokens, $dml_key;
                $parens = 0;
            }
        }

        if ( !$dml_key ) {
            push @new_tokens, $token;
        }

        # Ensure that "GRANT ... TO user WITH GRANT OPTION" does not
        # get partially tagged as DML
        if ( $token eq 'GRANT' ) {
            $is_grant = 1;
        }
        elsif ( $token eq ';' ) {
            if ($is_grant) {
                $is_grant = 0;
            }
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
    my @new_tokens = ('');

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~dml_/ ) {
            push @new_tokens, @{ $dmls->{$token} };
        }
        else {
            push @new_tokens, $token;
        }
    }

    return @new_tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;

