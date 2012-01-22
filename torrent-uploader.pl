#!/usr/bin/perl

# Always! ;)
use strict;
use warnings;

use FindBin '$Bin';

# Only under development
use Data::Dumper;

# My libs
use lib $Bin.'/lib';
use nb;
use torrent;
use description;
use makescreens;
use graphic;

# Needed modules
use Getopt::Long; # to handle arguments
Getopt::Long::Configure ('bundling');
use Config::Simple;
use File::Find;
use Cwd 'abs_path';
use File::Basename;

my($scene, $type, $make_screens, $nfo_file, $silent, $torrent_file, $work_dir, $torrent_dir, $no_unrar, $no_screens, $type_fallback, $tmp_config);
GetOptions ('c|config-file=s' => \$tmp_config, 'f|type-fallback=s' => \$type_fallback, 'no-unrar' => \$no_unrar, 'torrent-file=s' => \$torrent_file,'q|silent' => \$silent,'s|scene' => \$scene, 't|type=s' => \$type, 'work-dir=s' => \$work_dir, 'torrent-dir=s' => \$torrent_dir, 'no-screens' => \$no_screens, 'nfo=s' => \$nfo_file) or die("Wrong input");

# Handle config.
my $config_file = "./torrent-uploader.cfg";
$config_file = $ENV{"HOME"}."/torrent-uploader.cfg" if (-r $ENV{"HOME"}."/torrent-uploader.cfg");
$config_file = $tmp_config if ($tmp_config and (-r $tmp_config));

#print $config_file."\n";
my $cfg = new Config::Simple();
$cfg->read($config_file) or die "CONFIG ERROR: ".$cfg->error();
$make_screens = 1 if($cfg->param('make_screens') eq "yes");
$make_screens = 0 if $no_screens;
$make_screens = 0 unless $cfg->param('imgur_key');
$work_dir = $cfg->param('work_dir') unless $work_dir;
$torrent_dir = $cfg->param('torrent_dir') unless $torrent_dir;
my $mancreate = 1;
$mancreate = 0 if $silent;
#$no_unrar = 1 if $torrent_file;

my %glob_vars = ();
my @checked_files;
my $input;

eval {init(abs_path($ARGV[0])); };
my $error = $@ if $@;
if ($error) {
	print $error."\n" unless $silent;
	open(my $ERR, ">>", $ENV{"HOME"}."/.tu-err.log") or die($!);
	print $ERR "ERROR: ".$@."\n";
	close($ERR);
}
#print Dumper(\%glob_vars);
#print $glob_vars{screens}[0];

sub init {
	$input = shift;
	my $basename = basename($input);
	my $release = $basename;
	if (-d $input) { #is a directory
		#$release = $basename;
		# do needed operation on files!
		find (\&files_do, $input);
	} elsif (-r $input) { # is a readable file
		$no_unrar = 1;
		makescreens() if ($make_screens and $input =~ /.*\.(avi|mkv|mp4)$/);
		if($nfo_file and -r $nfo_file) {
			print "Stripping nfof." unless $silent;
			my $description = description->new( {
				nfo_file => $nfo_file,
				manual_create_possible => $mancreate,
			} );
			$glob_vars{'desc'} = $description->{'desc'};
		}
		$release =~ m/.*(\..*)$/;
		my $extension = $1;
	    $release =~ s/$extension//;
	} else { # Not a file, or its not readable!
		print STDERR $input." is not a file, or its not readable!";
		return 0;
	}
	unless ($glob_vars{'desc'}) {
		my $description = description->new({nfo_file => $nfo_file, manual_create_possible => $mancreate});
		$glob_vars{'desc'} = $description->{'desc'};
	}

	# POSTER AND BANNER
	if($cfg->param('imgur_key') or $cfg->param('tmdb_key')){
		print "Trying to fetch banner or poster.\n" unless $silent;
		my $graphic = graphic->new( {
			imgur_key => $cfg->param('imgur_key'),
			tmdb_key => $cfg->param('tmdb_key')
		} );
		if($cfg->param('imgur_key') and $basename =~ /^(.*).S\d{1,}E?\d{0,}/) { # Series -> get poster
			my $series = $1;
			$series =~ s/\./ /g;
			$glob_vars{'image'} = $graphic->get_banner($series);
		} elsif($cfg->param('tmdb_key') and $glob_vars{'desc'} =~ /(tt\d{7})/) { # Movie and got imdb ID
			$glob_vars{'image'} = $graphic->get_poster($1);
		}
	}
	
	# Create torrent
	#my $create_torrent = 1;
	#$create_torrent = 0 if $torrent_file;
	#$create_torrent = 1 if $glob_vars{'unrar_done'};
	#if ($create_torrent) {
	if ($glob_vars{'unrar_done'} or (!$torrent_file and !$glob_vars{'unrar_done'})) {
		print "Creating torrent..\n" unless $silent;
		my $torrent = torrent->new( {
			announce_url => 'http://jalla.com',
			file => $input,
			save_path => $work_dir,
			no_unrar => $no_unrar,
		} );
		$torrent_file = $torrent->{torrent_file};
	}
	die('Something unexpected whent wrong under torrent-creation') unless $torrent_file;
	
	# prepare descr
	if($glob_vars{'image'}) {
		$glob_vars{'desc'} = "[imgw]".$glob_vars{'image'}."[/imgw]\n".$glob_vars{'desc'};
	}
	if($glob_vars{'screens'}) {
		$glob_vars{'desc'} .= "\n";
		my $count = 0;
		foreach(@{$glob_vars{'screens'}}) {
			$glob_vars{'desc'} .= "\n" if 1 & $count;
			$glob_vars{'desc'} .= "[URL=".$_->{'screen'}."][img]".$_->{'thumb'}."[/img][/URL]";
		}
	}
	
	# UPLAOD TORRENT #
	# Create nb
	my $logging = 1;
	$logging = 0 if $silent;
	my $nb = nb->new( {
		url => $cfg->param('site_url'),
		username => $cfg->param('username'),
		password => $cfg->param('password'),
		download_path => $torrent_dir,
		fastresume => 1,
		logging => $logging,
	} );
	#find type
	$type = $nb->find_type($basename, $type_fallback) unless $type;
	die("Unable to detect type, try -t|--type") unless $type;

	#Upload
	#my $upload = "https://norbits.net/details.php?id=68928";
	my $upload = $nb->upload(toutf8($release), $torrent_file, toutf8($glob_vars{'desc'}), $type, $nfo_file, $scene);
	die("Opplasting mislykktes") unless $upload;
	
	# Download
	$input =~ s/\Q$basename\E//;
	my $uri = $nb->download($upload, $input);
	die("Error downloading torrent ".$upload) unless $uri;
	print "DONE: ".$uri."\n" unless $silent;
}

sub files_do {
	my $infile = $_;
	my $fullpath = $File::Find::name;
	return if (grep(/\Q$fullpath\E/, @checked_files));
	push(@checked_files, $File::Find::name);
	if($make_screens and $infile =~ /.*\.(avi|mkv|mp4|wmv)$/) { # Make screens
		makescreens($File::Find::name);
	}
	if(!$nfo_file and $infile =~ /.*\.nfo/) {
		print "Stripping nfos.\n" unless $silent;
		my $description = description->new( {
			nfo_file => $File::Find::name,
			manual_create_possible => $mancreate,
		} );
		$glob_vars{'desc'} = $description->{'desc'};
		$nfo_file = $File::Find::name;
	}
	if($infile =~ /.*\.part0*1\.rar$/ and !$no_unrar) {
		print "Unraring files\n" unless $silent;
		system($cfg->param('unrar')." x -inul -y '".$File::Find::name."'") == 0 or die("Unable to unrar ".$File::Find::name);
		$glob_vars{'unrar_done'} = 1;
		find (\&files_do, $input);
	} elsif ($infile !~ /.*\.part\d+\.rar$/ and $infile =~ /.*\.rar$/ and !$no_unrar) {
		print "Unraring file\n" unless $silent;
		system($cfg->param('unrar')." x -inul -y '".$File::Find::name."'") == 0 or die("Unable to unrar ".$File::Find::name);
		$glob_vars{'unrar_done'} = 1;
		find (\&files_do, $input);
	}
	$scene = 1 if $infile =~ /.*\.rar$/;
}

sub makescreens {
	my $mediafile = shift;
	return if $mediafile =~ /sample/;
	print "Making screens..\n" unless $silent;
	for(my $i = 1; $i <= 2; $i++) {
		my $s = 60 * $i;
		my $screen = makescreens->new( {
			mediafile => $mediafile,
			imgur_key => $cfg->param('imgur_key'),
			ss => $s,
			dir => $work_dir."/",
		} );
		if ($screen->{'screen'} and $screen->{'thumb'}) {
			push(@{$glob_vars{'screens'}}, {screen => $screen->{'screen'}, thumb => $screen->{'thumb'}});
		}
	}
}

sub toutf8 {
	my $text = shift;
	return Encode::encode("iso-8859-1", Encode::decode("utf8", $text));
}