#!/usr/bin/perl

# Always! ;)
use strict;
use warnings;

use FindBin '$Bin';

# Only under development
# testedit
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
use DateTime;

my($scene, $category, $make_screens, $nfo_file, $silent, $torrent_file, $work_dir, $torrent_dir, $no_unrar, $no_screens, $cat_fallback, $tmp_config, $no_mancreate, $mancreate, $manual_descr);
GetOptions ('c|config-file=s' => \$tmp_config, 
  'f|cat-fallback=s' => \$cat_fallback, 
  'no-unrar' => \$no_unrar, 
  'torrent-file=s' => \$torrent_file,
  'q|silent' => \$silent,
  's|scene' => \$scene, 
  't|category=s' => \$category, 
  'work-dir=s' => \$work_dir, 
  'torrent-dir=s' => \$torrent_dir, 
  'no-screens' => \$no_screens, 
  'nfo=s' => \$nfo_file,
  'no-manual-descr' => \$no_mancreate,
  'force-manual-descr' => \$manual_descr) or print STDERR "Wrong input\n" and usage();

#print $manual_descr."\n";
# Handle config.
my($config_file);
if($tmp_config) {
  print STDERR $tmp_config." is not a file.\n" and usage() unless -r $tmp_config;
  $config_file = $tmp_config;
} elsif(-r $ENV{"HOME"}."/torrent-uploader.cfg") {
  $config_file = $ENV{"HOME"}."/torrent-uploader.cfg";
} elsif(-r "./torrent-uploader.cfg") {
  print STDERR "WARNING: using the config file in the script folder, this might be not what you want!\n" unless $silent;
  $config_file = "./torrent-uploader.cfg";
} else {
  print STDERR "No config file found!";
  usage();
}
#print $config_file."\n";
my $cfg = new Config::Simple();
$cfg->read($config_file) or die "CONFIG ERROR: ".$cfg->error();

if($cfg->param('make_screens') eq "yes" and !$no_screens) {
  if(defined $cfg->param('imagehost') and $cfg->param('imagehost') eq 'imgur' and !$cfg->param('imgur_key')) {
    print STDERR "WARNING: Cannot create screens, missing imgur key.\n" unless $silent;
    $make_screens = 0;
  } elsif(defined $cfg->param('imagehost') and $cfg->param('imagehost') eq 'imageshack' and !$cfg->param('ihack_keys')) {
    print STDERR "WARNING: Cannot create screens, missing imageshack key.\n" unless $silent;
    $make_screens = 0;
  } elsif(defined $cfg->param('imagehost') and $cfg->param('imagehost') eq 'imagebam' and !($cfg->param('ib_api_key') and $cfg->param('ib_api_secret') and $cfg->param('ib_o_token') and $cfg->param('ib_o_token_secret'))) {
    print STDERR "WARNING: Cannot create screens, missing imagebam key(s).\n" unless $silent;
    $make_screens = 0;
  } elsif(not defined $cfg->param('imagehost') and $cfg->param('imgur_key')) {
    print STDERR "Imagehost not set, but imgur key set, using imgur.\n" unless $silent;
    $cfg->param('imagehost', 'imgur');
    #print $cfg->param('imagehost')."\n";
    #$cfg->save();
    $make_screens = 1;
  } elsif(!$cfg->param('imagehost')) {
    $make_screens = 0;
    print STDERR "Image host not set, cannot make screens!\n" unless $silent;
  } else {
    $make_screens = 1;
  }
} else {
  $make_screens = 0;
}

if($work_dir and !(-d $work_dir)) {
  print STDERR "Work dir (".$work_dir.") is not a directory.\n";
  usage();
} elsif(-d $cfg->param('work_dir') and !$work_dir) {
  $work_dir = $cfg->param('work_dir');
} elsif(!$work_dir) {
  print STDERR "No workdir set.\n";
  usage();
}
#print $work_dir."\n";
#$work_dir = $cfg->param('work_dir') unless $work_dir;

if($torrent_dir and !(-d $torrent_dir)) {
  print STDERR "torrent dir (".$torrent_dir.") is not a directory.\n";
  usage();
} elsif(-d $cfg->param('torrent_dir') and !$torrent_dir) {
  $torrent_dir = $cfg->param('torrent_dir');
} elsif(!$torrent_dir) {
  print STDERR "No torrent dir set.\n";
  usage();
}

my %cats;
if($category) {
  ($cats{'main'}, $cats{'sub1'}, $cats{'sub2'}, $cats{'sub3'}) = split(',',$category, 4);
}
my %cats_fallback;
if($cat_fallback) {
  ($cats_fallback{'main'}, $cats_fallback{'sub1'}, $cats_fallback{'sub2'}, $cats_fallback{'sub3'}) = split(',',$cat_fallback, 4);
}

#print $torrent_dir."\n";
#$torrent_dir = $cfg->param('torrent_dir') unless $torrent_dir;

print STDERR "Torrent file(".$torrent_file.") is not a readable file.\n" and usage() if $torrent_file and !(-r $torrent_file);
print STDERR "NFO file(".$nfo_file.") is not a readable file.\n" and usage() if $nfo_file and !(-r $nfo_file);

if($silent) {
  $mancreate = 0;
} elsif($no_mancreate) {
  $mancreate = 0;
} else {
  $mancreate = 1;
}

my %glob_vars = ();
my @checked_files;
my $input;

print STDERR "Wrong input!\n" and usage() unless defined($ARGV[0]) and (-f $ARGV[0] or -d $ARGV[0]);

eval {init(abs_path($ARGV[0])); };
my $error = $@ if $@;
if ($error) {
  my $dt = DateTime->now;
  my $date = $dt->ymd;
  my $time = $dt->hms;
	print $error."\n" unless $silent;
	open(my $ERR, ">>", $ENV{"HOME"}."/.tu-err.log") or die($!);
	print $ERR $date." ".$time." ERROR: ".$error."\n";
	close($ERR);
}
#print Dumper(\%glob_vars);
#print $glob_vars{screens}[0];

sub usage {
  print "USAGE: $0 [OPTIONS] [INPUT FILE/FOLDER]\n".
  "-c|--config-file=FILE  Set config file, default is ~/torrent-uploader.cfg and fallback to ./torrent-uploader.cfg\n".
  "--no-unrar             Disables unraring.\n".
  "--torrent-file=FILE    Set a torrent file if you already have one, otherwise it will create one.\n".
  "-q|--silent            Silenceing the script(aka no output)\n".
  "-s|--scene             Set if you are uploading a scene release. default is no, but it will assume scene if rar files is present.\n".
  "--work-dir=DIR         To override the work dir set in config.\n".
  "--torrent-dir=DIR      To override the torrent dir set in config.(Where torrents are downloaded).\n".
  "--no-screens           Disable screen making.\n".
  "--nfo=FILE             Set a nfo file to use as description. default is finding a .nfo in the path.\n".
  "--no-manual-descr      Set if manual creation of description is not possible, this is set auto when silent.\n".
  "-t|--category=CATS     Set category, comma seperated list: main,sub1,sub2,sub3 (IDs)\n".
  "-f|--cat-fallback=CATS Set fallback category if category not found. same format as above.\n".
  "--force-manual-descr   Do manual descr even if nfo is found, do not work with silent!\n";
  exit 0;
}

sub init {
	$input = shift;
	my $basename = basename($input);
	my $release = $basename;
	my $extension = "";
	if (-d $input) { #is a directory
		#$release = $basename;
		# do needed operation on files!
		find (\&files_do, $input);
	} elsif (-r $input) { # is a readable file
		$no_unrar = 1;
		makescreens($input) if ($make_screens and $input =~ /.*\.(avi|mkv|mp4)$/);
		if(($nfo_file and -r $nfo_file) and !(-r $work_dir."/nfos/".$release.".nfo") and !$manual_descr) {
			print "Stripping nfo." unless $silent;
			my $description = description->new( {
				nfo_file => $nfo_file,
				manual_create_possible => $mancreate,
			} );
			$glob_vars{'desc'} = $description->{'desc'};
		}
		if($release =~ m/.*(\..*)$/) {
      $extension = $1;
      $release =~ s/$extension//;
    }
	} else { # Not a file, or its not readable!
		print STDERR $input." is not a file, or its not readable!";
		return 0;
	}
	unless ($glob_vars{'desc'}) {
		if (-r $work_dir."/nfos/".$release.".nfo") {
			my $description = description->new( {
				nfo_file => $work_dir."/nfos/".$release.".nfo",
				manual_create_possible => $mancreate,
			} );
			$glob_vars{'desc'} = $description->{'desc'};
		} elsif (-r $work_dir."/nfos/".$release.$extension.".nfo") {
			my $description = description->new( {
				nfo_file => $work_dir."/nfos/".$release.$extension.".nfo",
				manual_create_possible => $mancreate,
			} );
			$glob_vars{'desc'} = $description->{'desc'};
		}
	}
	unless ($glob_vars{'desc'}) {
		my $description = description->new({nfo_file => $nfo_file, manual_create_possible => $mancreate, forcemanual => $manual_descr});
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
			$glob_vars{'desc'} .= "\n" if ($count % 2 == 0);
			$glob_vars{'desc'} .= "[URL=".$_->{'screen'}."][img]".$_->{'thumb'}."[/img][/URL]";
      $count++;
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
  
  #Find new cats
  %cats = $nb->find_categories($basename, %cats_fallback) unless $cats{'main'};
  die("Unable to detect categories") unless $cats{'main'};

	#Upload
	#my $upload = "https://norbits.net/details.php?id=68928";
	my $upload = $nb->upload(toutf8($release), $torrent_file, toutf8($glob_vars{'desc'}), $nfo_file, $scene, %cats);
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
	if(!$nfo_file and $infile =~ /.*\.nfo/ and !$manual_descr) {
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
		#print($cfg->param('unrar')." x -inul -y '".$File::Find::name."'");
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
  my @ihack_keys = $cfg->param('ihack_keys');
	for(my $i = 1; $i <= 2; $i++) {
		my $s = 60 * $i;
		my $screen = makescreens->new( {
			mediafile => $mediafile,
			imgur_key => $cfg->param('imgur_key'),
      ihack_keys => @ihack_keys,
      ib_keys => {
        api_key => $cfg->param('ib_api_key'),
        api_secret => $cfg->param('ib_api_secret'),
        o_token => $cfg->param('ib_o_token'),
        o_token_secret => $cfg->param('ib_o_token_secret'),
      },
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
