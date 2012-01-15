#!/usr/bin/perl
package nb;

use strict;
use warnings;
use HTTP::Cookies;

use lib './lib';
use fastresume;

BEGIN {
	#use Exporter;
	#our @ISA = qw(Exporter);
	our @EXPORT = qw(new upload download test);
}

use WWW::Mechanize;

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		url => '',
		username => '',
		password => '',
		download_path => '.',
		fastresume => 1,
		logging => 0,
	);
	
	# loop trough and set the properties to self.
	for my $property ( keys %self ) {
		if (exists $param_rh->{$property}) {
			$self{$property} = delete $param_rh->{$property};
		}
	}

	# warn on property not supported.
	# Should not really happen unless someone messed with the code.
	# Might be nice for debug.
	if ($self{logging}) {
		for my $property ( keys %{$param_rh} ) {
			print "WARN: $property is not a supported parameter";
		}
	}
	
	# Check that everything is set!
	die("URL must be set") unless $self{url};
	die("username must be set") unless $self{username};
	die("passord must be set") unless $self{password};
	
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
	my $cookie_jar = HTTP::Cookies->new( file => "nb_cookies.dat", autosave => 1 );
	$self{mech} = WWW::Mechanize->new(cookie_jar => $cookie_jar, autocheck => 0);
	#print $self{url}."\n";
	die("Login to ".$self{url}." FAILED") unless login(%self);
	print "login to ".$self{url}." sucessfull!\n" if $self{logging};
	return bless \%self, $class;
}

sub login {
	my %self = @_;
	
	print "Logging in.\n" if $self{logging};
	$self{mech}->default_header('Referer' => $self{url}."/login.php");
	$self{mech}->post($self{url}."/takelogin.php", [ "username" => $self{username}, "password" => $self{password} ]);
	
	return 0 unless $self{mech}->success;
	return 0 if ($self{mech}->uri eq $self{url}."/takelogin.php");
	return 1;
}

sub upload {
	my ( $self, $release_name, $torrent_path, $description, $type, $nfo_path, $scene ) = @_;
	if ($scene) { $scene = "yes"; } else { $scene = "no"; }
	print "Uploading torrent.\n" if $self->{logging};
	die("input missing") unless ($release_name and $torrent_path and $description and $type);
	$self->{mech}->get($self->{url}."/upload.php");
	die("Could not reach ".$self->{url}."/upload.php") unless ($self->{mech}->success);
	$self->{mech}->add_header('Accept-Charset' => 'iso-8859-1');
	my $form = $self->{mech}->form_name( "upload" );
	$form->accept_charset("iso-8859-1");
	$self->{mech}->submit_form(
		form_name => "upload",
		fields => {
			MAX_FILE_SIZE => "3000000",
			file => $torrent_path,
			filetype => "2",
			name => $release_name,
			nfo => $nfo_path,
			scenerelease => $scene,
			descr => $description,
			type => $type,
			anonym => "yes"
		}
	);
	die("Could not reach ".$self->{url}."/takeupload.php") unless ($self->{mech}->success);
	
	my $uri = $self->{mech}->uri();
	if ($uri =~ /details\.php/) {
		return $uri;
	} else {
		if ($self->{logging}) {
			if ($self->{mech}->content =~ /<h3>Mislykket\sopplasting!<\/h3>\n<p>(.*)<\/p>/) {
				print $1."\n";
			}
			if ($self->{mech}->content =~ /<h3>(.*)<\/h3>/) {
				print $1."\n";
			}
		}
		return 0;
	}
}

sub download {
	my ( $self, $uri, $file_path ) = @_;
	print "Downloading torrent.\n" if $self->{logging};
	$self->{mech}->get($uri);
	my $filename = "undef.torrent";
	if ($self->{mech}->content =~ /download\.php\/\d+\/(.+)\.torrent"/) {
		$filename = $1;
	} else {
		return 0;
	}
	$self->{mech}->follow_link( url_regex => qr/download/i );
	die("Could not download torrent") unless $self->{mech}->success;
	open(my $TORRENT_FILE, ">", $self->{download_path}."/".$filename.".torrent") or die("Could not write .torrent to path");
	my $tfile = $self->{mech}->content;
	$tfile = fastresume::fastresume($tfile, $file_path) if $self->{fastresume};
	print $TORRENT_FILE $tfile;
	close($TORRENT_FILE);
	return $uri;
}

sub test {
	my ( $self, $arg ) = @_;
	print "wut\n";
	return $self->{url};
}

sub find_type {
	my ( $self, $release, $fallback ) = @_;
	if ($release =~ m/S\d{1,}/i or $release =~ m/(PDTV|HDTV)/i) { #IS TV
		if ($release =~ m/XviD/i) { return "1" }
		if ($release =~ m/x264/i) { return "29" }
		if ($release =~ m/DVDR/i) {return "27" }
	} else { #IS MOVIE
		if ($release =~ m/x264/i) { return "28" }
		if ($release =~ m/XviD/i) { return "25" }
		if ($release =~ m/MP4/i) { return "26" }
		if ($release =~ m/MPEG/i) { return "24" }
		if ($release =~ m/(BluRay|Blu-Ray)/i) { return "19" }
		if ($release =~ m/DVDR/i) {return "20" }
	}
	return $fallback if $fallback;
	return 0;
}

1;