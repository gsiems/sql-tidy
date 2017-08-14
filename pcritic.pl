#!/usr/bin/env perl
use warnings;
use strict;

use Perl::Critic;
use FindBin;

my $critic = Perl::Critic->new();

my $path = "$FindBin::Bin";

my @files = `find $path -type f -name "*.p[lm]" | grep -v git_ignore`;
chomp @files;

foreach my $file (@files) {
    my @violations = $critic->critique($file);
    if (@violations) {
        print "\n################################\n$file:\n", @violations;
    }
}
