#!/usr/bin/perl
package torrent;

use strict;
use warnings;

use File::Basename;
use Cwd 'abs_path';

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		announce_url => '',
		file => '',
		save_path => '.',
		piece_length => 41941304,
		buildtorrent => 1,
		no_unrar => 0,
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
		if ($self{no_unrar}) {
			system('buildtorrent -q -p1 -L '.$self{piece_length}.' -a '.$self{announce_url}.' "'.$self{file}.'" "'.$self{save_path}.'/'.$filename.'.torrent"') == 0 or die("Creating torrent failed!");
		 } else {
			my $filelist = create_filelist($self{save_path}."/filelist.txt", $self{file});
			system('buildtorrent -q -p1 -L '.$self{piece_length}.' -a '.$self{announce_url}.' -f "'.$filelist.'" -n "'.$filename.'" "'.$self{save_path}.'/'.$filename.'.torrent"') == 0 or die("Creating torrent failed!");
			$self{torrent_file} = $self{save_path}.'/'.$filename.'.torrent';
			unlink($self{save_path}."/filelist.txt")
		}
	} else {
		print "Only buildtorrent is supported ATM.\n";
	}
	return bless \%self, $class;
}

sub create_filelist {
	my ($filelist, $path) = @_;
	open( my $FILE, ">", $filelist ) or die($!);
	opendir( my $DIR, $path ) or die($!);
	while (my $filename = readdir($DIR)) {
		unless ($filename =~ /(^\.|\.rar$|\.r\d\d$|\.sfv$)/) {
			my $syspath = abs_path($path."/".$filename);
			my $torpath = $filename;
			if (-d $syspath) {
				opendir(my $DIR2, $syspath) or die($!);
				while (my $filename2 = readdir($DIR2)) {
					print $FILE $syspath."/".$filename2."|".$torpath."/".$filename2."\n" unless($filename2 =~ /^\./);
				}
				closedir($DIR2);
			} else {
				print $FILE $syspath.'|'.$torpath."\n";
			}
		}
	}
	closedir($DIR);
	close($FILE);
	return $filelist;
}

1;