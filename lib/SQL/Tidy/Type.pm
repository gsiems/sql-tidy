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

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;
    return @tokens;
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
