#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use SQL::Tidy;

my $VERSION = '0.2';

my %opts = get_options();

my $source_code;
if ( exists $opts{input_file} && -f $opts{input_file} ) {
    $source_code = _slurp_file( $opts{input_file} );
}
else {
    die "no input file specified\n";
}

my $tidy      = SQL::Tidy->new( \%opts );
my $tidy_code = $tidy->tidy($source_code);

if ( $opts{output_file} ) {
    open my $OUT, '>', $opts{output_file} || die "Could not open " . $opts{output_file} . " for output. $!\n";
    print $OUT $tidy_code;
    close $OUT;
}
else {
    print $tidy_code . "\n";
}

exit;

sub get_options {

    Getopt::Long::Configure(qw(bundling));
    my %opts = ();
    GetOptions(
        "use-tabs"   => \$opts{use_tabs},
        "tab-size=i" => \$opts{tab_size},

        "max-line-length=i" => \$opts{max_line_width},
        "min-line-length=i" => \$opts{min_line_width},

        "keywords-case=s"        => \$opts{keywords_case},
        "non-keywords-case=s"    => \$opts{non_keywords_case},
        "leading-commas"         => \$opts{leading_commas},
        "no-space-before-parens" => \$opts{no_space_before_parens},
        "no-space-after-parens"  => \$opts{no_space_after_parens},
        "no-space-after-comma"   => \$opts{no_space_after_comma},

        "remove-comments" => \$opts{remove_comments},
        "convert-decode"  => \$opts{convert_decode},
        "convert-nvl"     => \$opts{convert_nvl},
        "convert-nvl2"    => \$opts{convert_nvl2},
        "convert-all"     => \$opts{convert_all},
        "default-case"    => \$opts{default_case},
        "dialect=s"       => \$opts{dialect},
        "i=s"             => \$opts{input_file},
        "input-file=s"    => \$opts{input_file},
        "o=s"             => \$opts{output_file},
        "output-file=s"   => \$opts{output_file},
        "h"               => \$opts{help},
        "help"            => \$opts{help},
        "V"               => \$opts{version},
        "version"         => \$opts{version},
    );

    if ( $opts{version} ) {
        print "sqltidy Version $VERSION\n";
        exit;
    }

    if ( $opts{help} ) {
        my @help = `perldoc $0`;
        print @help;
        exit;
    }

    return %opts;
}

sub _slurp_file {
    local ( *ARGV, $/ );
    @ARGV = shift;
    <>;
}

__END__
