#!/usr/bin/perl
# -*- mode: cperl; cperl-indent-level: 4 -*-
# $ peek-7zs.pl $
#
# Author: Tomi Ollila -- too ät iki piste fi
#
# Created: Sat 03 Aug 2019 23:13:53 EEST too
# Last modified: Sun 04 Aug 2019 18:32:48 +0300 too

# Can be used to extract embedded .7z files from
# e.g. Sailfish Application SDK Installer...

# SPDX-License-Identifier: Apache-2.0

use 5.8.1;
use strict;
use warnings;

die "Usage: $0 file\n" unless @ARGV == 1;

open I, '<', $ARGV[0] or die;

my $no = 0;

my @offsets;

print "Seek 7z offsets in $ARGV[0]:\n";
while (1) {
    my $co = $no;
    sysread I, $_, 1048576;
    last if ((length) <= 6);
    $no = $co + (length) - 5;
    my $oco = $co;
    while (1) {
	my $i = index $_, "7z\xbc\xaf\x27\x1c";
	sysseek(I, -5, 1), last if $i < 0;
	$co += $i;
	print ' ', $co;
	push @offsets, $co++;
	$_ = substr $_, $i + 1;
    }
    print "\n" if $oco != $co;
}
push @offsets, sysseek(I, 0, 1);
print "\n\n";

#shift @offsets for (1..0);

# for 7z need to split from offset to next to a file, and think what
# are interesting (size at least something)...

sub copyIO($) {
    my $left = $_[0];
    while ($left > 0) {
	my $l = sysread I, $_, ($left > 1024 * 1024)? (1024 * 1024): $left;
	die "$l: $left: $!" if $l <= 0;
	syswrite O, $_, $l;
	$left -= $l;
    }
}

my $prev = 1024 * 1024 * 1024;
my $num = 10;
my @files;
foreach (@offsets) {
    my $o = $_;
    #print $o - $prev, "\n";
    my $dist = $o - $prev;
    if ($dist > 50 * 1024 * 1024) {
	$num++;
	my $fn = "zf-$num-o$prev.7z";
	print "Content at offset $prev, max size $dist -> $fn\n";
	open O, '>', $fn or die;
	sysseek I, $prev, 0;
	copyIO $dist;
	close O;
	push @files, $fn;
	unless (fork) {
	    open STDOUT, '>', "$fn.l" or die;
	    exec qw/7z l/, $fn;
	    die;
	}
	wait;
	# truncate could be added here...
	#print "-^-" x 20, "\n";
    }
    else {
	print "Content at offset $prev, max size $dist; skipped (small)\n";
    }
    $prev = $o;
}
pop @offsets;

while (1) {
    print join "\n", @files;
    print "\n";
    exit
}


__END__

foreach (@offsets) {
    sysseek I, $_ - 96, 0;
    unless (fork) { open STDIN, '<&I' or die; exec qw'hexdump -C -n 128'; die }
    wait;
}
