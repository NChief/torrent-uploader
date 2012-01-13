#!/usr/bin/perl
package makescreens;

use strict;
use warnings;

use Image::Thumbnail;
use Image::Imgur;

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		mediafile => '',
		imgur_key => '',
		ss => 60,
		dir => '.',
	);
	
	# loop trough and set the properties to self.
	for my $property ( keys %self ) {
		if (exists $param_rh->{$property}) {
			$self{$property} = delete $param_rh->{$property};
		}
	}
	
	die("info missing") unless ($self{mediafile} and $self{imgur_key});
	
	#system('mplayer -ss '.$self{ss}.' -vo png:z=9:outdir="'.$self{dir}.'" -ao null -frames 2 " ' . $self{mediafile} . '"') == 0 or die("unable to make screen of ".$self{mediafile});
	system('mplayer -ss '.$self{ss}.' -vo png:z=9:outdir="'.$self{dir}.'" -ao null -frames 2 "' . $self{mediafile} . '" > /dev/null 2>&1') == 0 or die("unable to make screen of ".$self{mediafile});
	#print 'mplayer -ss '.$self{ss}.' -vo png:z=9:outdir="'.$self{dir}.'" -ao null -frames 2 "' . $self{mediafile} . '"'."\n";
	#print 'mplayer -ss '.$self{ss}.' -vo png:z=9:outdir="'..'" -ao null -frames 2 "' . $self{mediafile} . '" > /dev/null 2>&1'."\n";
	
	my $imgur = new Image::Imgur(key => $self{imgur_key});
	my $img = $imgur->upload($self{dir}."00000002.png");
	err("Upload to imgur failed with code: ".$img) if (isNumeric($img));
	
	my $t1 = new Image::Thumbnail(
		size       => 300,
		create     => 1,
		input      => $self{dir}.'00000002.png',
		outputpath => $self{dir}.'thumb.png'
	);
	my $thumb = $imgur->upload($self{dir}."thumb.png");
	err("Upload to imgur of thumb failed with code: ".$img, $self{dir}) if (isNumeric($img));
	unlink($self{dir}."00000001.png", $self{dir}."00000002.png", $self{dir}."thumb.png");
	
	$self{screen} = $img;
	$self{thumb} = $thumb;
	
	return bless \%self, $class;
}

sub isNumeric {
	my $input = shift;
	if ( $input =~ /^[\+-]?[0-9]*\.?[0-9]*$/ && $input !~ /^[\. ]*$/ ) {
		return 1;
	} else {
		return 0;
	}
}

sub err {
	my ($err, $dir) = @_;
	unlink($dir."00000001.png", $dir."00000002.png", $dir."thumb.png");
	die($err);
}

1;