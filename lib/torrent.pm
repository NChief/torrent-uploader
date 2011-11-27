#!/usr/bin/perl
package torrent;

use strict;
use warnings;

use File::Basename;

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		announce_url => '',
		file => '',
		save_path => '.',
		piece_length => 41941304,
		buildtorrent => 1,
	);
	
	# loop trough and set the properties to self.
	for my $property ( keys %self ) {
		if (exists $param_rh->{$property}) {
			$self{$property} = delete $param_rh->{$property};
		}
	}
	
	die("info for making torrent missing.") unless ($self{announce_url} and $self{file} and $self{save_path});
	
	my $filename = basename($self{file});
	if($self{buildtorrent}) {
		system('buildtorrent -q -p1 -L '.$self{piece_length}.' -a '.$self{announce_url}.' "'.$self{file}.'" "'.$self{save_path}.'/'.$filename.'.torrent"') == 0 or die("Creating torrent failed!");
		$self{torrent_file} = $self{save_path}.'/'.$filename.'.torrent';
	} else {
		print "Only buildtorrent is supported ATM.\n";
	}
	return bless \%self, $class;
}

1;