#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use SQL::Tidy;

# TODO: Add option for verbosity (show all, only show failed, display summary # failed vs. total)
# TODO: Add option for saving results of failed tests
# TODO: Add option to exit on first fail
# TODO: Replace `find ...` with readdir and unlink
# TODO: UTF-8 slurping
# TODO: Set the engine according to the file name (ora_* vs. pg_* vs. neither (which should use the generic engine))

# Cleanup any previous failures
`find failed -name "*.sql" -exec rm {} \\;`;

my @source_files = @ARGV;
if ( not @source_files ) {
    @source_files = `find input/*sql`;
}
chomp @source_files;

my $passed       = 0;
my $failed       = 0;
my $tested_count = scalar @source_files;

print qq{
#####################################################
Testing $tested_count files
#####################################################

};
foreach my $source_file (@source_files) {
    my $expected_file = $source_file;
    $expected_file =~ s|input/|expected/|;

    my $source_code = _slurp_file($source_file);

    my @params = grep { $_ =~ m/^\-\- params:/ } split "\n", $source_code;
    my %h;
    if (@params) {
        foreach my $line (@params) {
            chomp $line;
            $line =~ s/^\-\- args:\s+//;
            foreach my $param ( split /\s+/, $line ) {
                my ( $key, $val ) = split '=', $param;
                $h{$key} = $val;
            }
        }
    }

    my $expected_code = '';
    if ( -f $expected_file ) {
        $expected_code = _slurp_file($expected_file);
    }
    else {
        $expected_code = $source_code;
    }

    # Check filename to determine dialect to use
    my ($filename) = ( split '/', $source_file )[-1];
    my $dialect = 'Default';
    if ( $filename =~ m/^pg_/i ) {
        $h{dialect} ||= 'Pg';
    }
    elsif ( $filename =~ m/^ora_/i ) {
        $h{dialect} ||= 'Oracle';
    }

    my $tidy      = SQL::Tidy->new( \%h );
    my $tidy_code = $tidy->tidy($source_code);

    # Note that we don't consider extra new-lines at the end of the file
    # as a fail--
    $tidy_code     = tidy_finale($tidy_code);
    $expected_code = tidy_finale($expected_code);

    if ( $tidy_code eq $expected_code ) {
        print "PASS: $source_file\n";
        $passed++;
    }
    else {
        print "FAIL: $source_file\n";
        $failed++;

        my $failed_file = $source_file;
        $failed_file =~ s|input/|failed/|;
        open my $fh, '>', $failed_file;
        print $fh $tidy_code;
        close $fh;
    }
}

print qq{
#####################################################
Total Tested:   $tested_count
Number Passed:  $passed
Number Failed:  $failed

};

sub tidy_finale {
    # Clean-up the "ragged" new-lines at the end of the code

    my ($code) = @_;

    my @ary = split( /(\n)/, $code );
    if (@ary) {
        while ( $ary[-1] eq '' or $ary[-1] eq "\n" ) {
            pop @ary;
        }
    }
    return join( '', @ary ) . "\n\n";
}

sub _slurp_file {
    local ( *ARGV, $/ );
    @ARGV = shift;
    <>;
}
