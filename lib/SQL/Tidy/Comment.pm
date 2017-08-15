package SQL::Tidy::Comment;
use strict;
use warnings;

use SQL::Tidy::Indent;

=head1 NAME

SQL::Tidy::Comment

=head1 SYNOPSIS

Tag and untag comments

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

    $self->{indent} = SQL::Tidy::Indent->new($args);

    return $self;
}

=item tag_comments ( tokens )

Replaces comment tokens with a tag and stores the original comment in a reference hash

Returns a hash-ref of the comment tags and the modified list of tokens

=cut

sub tag_comments {
    my ( $self, @tokens ) = @_;
    my @new_tokens = ( '', '' );
    push @tokens, ('', '');

    my %comments;
    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];

        my $key;
        if ( $token =~ m/^--/ ) {
            $key = '~~comment_eol_' . sprintf( "%06d", $idx );
            $comments{$key}{comment} = $token;
            $token = $key;
        }
        elsif ( $token =~ m/^\/\*/ ) {
            $key = '~~comment_blk_' . sprintf( "%06d", $idx );
            $comments{$key}{comment} = $token;
            $comments{$key}{indent}  = 0;

            if ($idx and $tokens[ $idx - 1 ] =~ $self->{space_re}) {
                $comments{$key}{indent} = $self->{indent}->to_tab_count($tokens[ $idx - 1 ]);
            }
            $token = $key;
        }

        if ($key) {
            if ( $new_tokens[-1] eq "\n" ) {
                $comments{$key}{newline_before} = 1;
            }
            elsif ( $new_tokens[-1] and $new_tokens[-1] =~ $self->{space_re} and $new_tokens[-2] eq "\n" ) {
                $comments{$key}{newline_before} = 1;
            }
            else {
                $comments{$key}{newline_before} = 0;
            }

            if ( $key =~ m/comment_eol/ ) {
                # by definition...
                $comments{$key}{newline_after} = 1;
            }
            elsif ( $tokens[ $idx + 1 ] eq "\n" ) {
                $comments{$key}{newline_after} = 1;
            }
            elsif ( $tokens[ $idx + 1 ] =~ $self->{space_re} and $tokens[ $idx + 2 ] eq "\n" ) {
                $comments{$key}{newline_after} = 1;
            }
            else {
                $comments{$key}{newline_after} = 0;
            }

            $key = undef;
        }

        push @new_tokens, $token;

    }
    return ( \%comments, @new_tokens );
}

=item untag_comments ( comments, tokens )

Takes the hash of comment tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag_comments {
    my ( $self, $comments, @tokens ) = @_;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~comment_eol/ ) {
            $tokens[$idx] = $comments->{$token}{comment};
        }
        if ( $token =~ m/^~~comment_blk/ ) {
            my $comment = $comments->{$token}{comment};
            $comment =~ s/\r//g;

            my $prev_token = ($idx) ? $tokens[ $idx - 1 ] : '';
            my $curr_indent = 0;
            if ( $prev_token =~ $self->{space_re} ) {
                $curr_indent = $self->{indent}->to_tab_count($prev_token);
            }

            my $indent_diff = $curr_indent - $comments->{$token}{indent};

            if ( $indent_diff > 0 ) {
                # Increase the indent by the diff
                my @ary = split "\n", $comment;

                my $dint = $self->{indent}->to_indent($indent_diff);

                foreach my $idx ( 1 .. $#ary ) {
                    my $line = $self->{indent}->add_indents($ary[$idx], $indent_diff);

                    $line =~ s/ +$//;
                    $ary[$idx] = $line;
                }
                $comment = join "\n", @ary;
            }
            elsif ( $indent_diff < 0 ) {
                # Decrease the indent by the diff
                my @ary = split "\n", $comment;

                $indent_diff = abs($indent_diff);

                foreach my $idx ( 1 .. $#ary ) {
                    my $line = $self->{indent}->subtract_indents($ary[$idx], $indent_diff);
                    $ary[$idx] = $line;
                }
                $comment = join "\n", @ary;
            }

            $tokens[$idx] = $comment;
        }
    }
    return @tokens;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
