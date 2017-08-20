package SQL::Tidy::Dialect;
use strict;
use warnings;

use Carp();

=head1 NAME

SQL::Tidy::Dialect

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over

=cut

=item new

Create, and return, a new instance of this

=cut

sub new {
    my ( $this, $args ) = @_;

    my $dialect = $args->{dialect} || 'Default';

    my $driver_class = "SQL::Tidy::Dialect::$dialect";
    eval qq{package                     # hide from PAUSE
        SQL::Tidy::_firesafe;           # just in case
        require $driver_class;          # load the driver
    };

    if ($@) {
        my $err = $@;
        Carp::croak("install_driver($driver_class) failed: $err\n");
    }

    my $self = $driver_class->new($args);

    return $self;
}

sub safe_ident_re {
    return qr /^[A-Za-z0-9_]+$/;
}

sub ddl_keywords {
    my %words;

    # TODO: Review reserved/not reserved. Oracle vs. Pg vs. Standard

    foreach my $word (
        qw(

        CREATE
        REPLACE
        ALTER
        DROP
        OR
        FORCE
        VIEW
        TABLE
        TRIGGER
        MATERIALIZED
        PACKAGE
        BODY
        FUNCTION
        PROCEDURE
        INDEX
        SEQUENCE
        FOREIGN
        KEY
        PRIMARY
        CONSTRAINT
        UNIQUE
        )
        )
    {

        $words{ uc $word }{word}     = $word;
        $words{ uc $word }{reserved} = 1;

    }

=pod
    foreach my $word (
        qw(

        )
        )
    {

        $words{ uc $word }{word} = $word;
        $words{ uc $word }{reserved} = 0;

    }
=cut

    return %words;
}

sub dml_keywords {
    my %words;

    # TODO: Review reserved/not reserved. Oracle vs. Pg vs. Standard

    foreach my $word (
        qw(

        AND
        AS
        BETWEEN
        BY
        CASE
        CAST
        CROSS
        DELETE
        DISTINCT
        ELSE
        END
        EXCEPT
        FOR
        FROM
        FULL
        GROUP
        HAVING
        IN
        INNER
        INSERT
        INTERSECT
        INTO
        IS
        ITERSECT
        JOIN
        LEFT
        LIKE
        MATCHED
        MERGE
        MINUS
        NATURAL
        NOT
        NULL
        ON
        OR
        ORDER
        OUTER
        OVER
        PARTITION
        PIVOT
        RIGHT
        SELECT
        SET
        THEN
        UNION
        UPDATE
        USING
        VALUES
        WHEN
        WHERE
        WITH

        )
        )
    {

        $words{ uc $word }{word}     = $word;
        $words{ uc $word }{reserved} = 1;

    }

=pod
    foreach my $word (
        qw(

        )
        )
    {

        $words{ uc $word }{word} = $word;
        $words{ uc $word }{reserved} = 0;

    }
=cut

    return %words;
}

sub pl_keywords {
    my %words;

    # TODO: Review reserved/not reserved. Oracle vs. Pg vs. Standard

    foreach my $word (
        qw(

        BEGIN
        CASE
        COMMIT
        ELSE
        ELSIF
        END
        EXCEPTION
        EXIT
        FETCH
        FOR
        IF
        LOOP
        RETURN
        ROLLBACK
        THEN
        WHEN

        )
        )
    {

        $words{ uc $word }{word}     = $word;
        $words{ uc $word }{reserved} = 1;

    }

=pod
    foreach my $word (
        qw(

        )
        )
    {

        $words{ uc $word }{word} = $word;
        $words{ uc $word }{reserved} = 0;

    }
=cut

    return %words;
}

=back

=head1 Copyright (C) 2017 gsiems.

This file is licensed under the Artistic License 2.0

=cut

1;
