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
		piece_length => 4194304,
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
			system('buildtorrent -q -p1 -l '.$self{piece_length}.' -a '.$self{announce_url}.' "'.$self{file}.'" "'.$self{save_path}.'/'.$filename.'.torrent"') == 0 or die("Creating torrent failed!");
		} else {
			my $filelist = create_filelist($self{save_path}."/".$filename."-filelist.txt", $self{file});
			system('buildtorrent -q -p1 -l '.$self{piece_length}.' -a '.$self{announce_url}.' -f "'.$filelist.'" -n "'.$filename.'" "'.$self{save_path}.'/'.$filename.'.torrent"') == 0 or die("Creating torrent failed!");
			
			unlink($self{save_path}."/filelist.txt")
		}
		$self{torrent_file} = $self{save_path}.'/'.$filename.'.torrent';
	} else {
		print "Only buildtorrent is supported ATM.\n";
	}
	return bless \%self, $class;
}

sub create_filelist {
	my ($filelist, $path) = @_;
	open( my $FILE, ">", $filelist ) or die($!);
	print $FILE filelist($path);
	close($FILE);
	return $filelist;
}

sub filelist {
	my ($path, $prepath) = @_;
	my $file = "";
	opendir(my $DIR, $path) or die($!);
	while(my $filename = readdir($DIR)) {
		next if $filename =~ /(^\.|\.rar$|\.[rst]\d\d$|\.sfv$|ninjabits)/;
		my $syspath = abs_path($path."/".$filename);
		my $torpath = ($prepath ? $prepath."/" : "").$filename;
		if (-d $syspath) {
			$file .= filelist($syspath, $torpath);
		} else {
			$file .= $syspath.'|'.$torpath."\n";
		}
	}
	return $file;
}

1;