#!/usr/bin/perl
package fastresume;

use strict;
use warnings;

use Convert::Bencode qw(bencode bdecode);

sub fastresume {
	my ($t, $d) = @_;
	$t = bdecode($t);

	unless (ref $t eq "HASH" and exists $t->{info}) {
		die "No info key.\n";
	}
	
	my $psize;
	if($t->{info}{"piece length"}) {
		$psize = $t->{info}{"piece length"};
	} else {
		die "No piece length key.\n";
	}

	my @files;
	my $tsize = 0;
	if (exists $t->{info}{files}) {
		for (@{$t->{info}{files}}) {
			push @files, join "/", $t->{info}{name},@{$_->{path}};
			$tsize += $_->{length};
		}
	} else {
		@files = ($t->{info}{name});
		$tsize = $t->{info}{length};
	}
	my $chunks = int(($tsize + $psize - 1) / $psize);

	if ($chunks*20 != length $t->{info}{pieces}) {
		die "Inconsistent piece information!\n";
	}
	
	$t->{libtorrent_resume}{bitfield} = $chunks;
	for (0..$#files) {
		unless (-e "$d$files[$_]") {
			die "$d$files[$_] not found.\n";
		}
		my $mtime = (stat "$d$files[$_]")[9];
		$t->{libtorrent_resume}{files}[$_] = { priority => 2, mtime => $mtime };
	};
	
	return bencode $t;
}

1;