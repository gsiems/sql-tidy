package SQL::Tidy::Type::Priv;
use base 'SQL::Tidy::Type';
use strict;
use warnings;

=head1 NAME

SQL::Tidy::Type::Priv

=head1 SYNOPSIS

Grant/revoke privs

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

=item tag ( tokens )


=cut

sub tag {
    my ( $self, @tokens ) = @_;
    my @new_tokens;
    my %priv;

    my $priv_key = '';

    foreach my $idx ( 0 .. $#tokens ) {

        my $token = $tokens[$idx];

        if ($priv_key) {

            if ( $token eq ';' ) {
                $priv_key = undef;
            }
        }
        elsif ( $token =~ m/^(GRANT|REVOKE)$/i ) {
            $priv_key = '~~priv_' . sprintf( "%04d", $idx );
            push @new_tokens, $priv_key;
        }

        if ($priv_key) {
            push @{ $priv{$priv_key} }, $token;
        }
        else {
            push @new_tokens, $token;
        }
    }

    return ( \%priv, @tokens );
}

=item untag ( privs, tokens )

Takes the hash of priv tags and restores their value to the token list

Returns the modified list of tokens

=cut

sub untag {
    my ( $self, $privs, @tokens ) = @_;
    my @new_tokens;

    foreach my $idx ( 0 .. $#tokens ) {
        my $token = $tokens[$idx];
        if ( $token =~ m/^~~priv_/ ) {
            push @new_tokens, "\n";
            push @new_tokens, @{ $privs->{$token} };
            push @new_tokens, "\n";
        }
        else {
            push @new_tokens, $token;
        }
    }

    return @new_tokens;
}

sub unquote_identifiers {
    my ( $self, @tokens ) = @_;

    my %keywords    = $Dialect->priv_keywords();
    my $stu_re      = $Dialect->safe_ident_re();
    my %pct_attribs = $Dialect->pct_attribs();

    return $self->_unquote_identifiers( \%keywords, \%pct_attribs, $stu_re, $case_folding, @tokens );
}

sub capitalize_keywords {
    my ( $self, @tokens ) = @_;
    my @new_tokens;
    my %keywords = $Dialect->priv_keywords();
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

1;
