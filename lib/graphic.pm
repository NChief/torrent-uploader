#!/usr/bin/perl
package graphic;

use strict;
use warnings;

use Image::Imgur;
use WWW::Mechanize;
use URI::URL;
use XML::Simple;
use JSON;
use Data::Dumper;

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		tmdb_key => '',
		imgur_key => '',
	);
	
	# loop trough and set the properties to self.
	for my $property ( keys %self ) {
		if (exists $param_rh->{$property}) {
			$self{$property} = delete $param_rh->{$property};
		}
	}
	
	die("You need to have a tmdb or imgur key") unless ($self{imgur_key} or $self{tmdb_key});
	
	$self{mech} = WWW::Mechanize->new(autocheck => 0);
	
	return bless \%self, $class;
}

sub get_banner {
	my ( $self, $show ) = @_;
	
	die("You need an imgur key for this") unless $self->{imgur_key};
	
	$self->{mech}->get('http://www.thetvdb.com/api/GetSeries.php?seriesname='.rawurlencode($show).'&language=no');
	if($self->{mech}->success) {
		my $xml = new XML::Simple;
		my $data = $xml->XMLin($self->{mech}->content, ForceArray => 1);
		#return $data;
		if($data->{'Series'}[0]->{'banner'}[0]) {
			my $tvdburl = 'http://thetvdb.com/banners/'.$data->{'Series'}[0]->{'banner'}[0];
			my $imgur = new Image::Imgur(key => $self->{imgur_key});
			my $image = $imgur->upload($tvdburl);
			die("Unable to upload ".$tvdburl." to imgur") if (isNumeric($image));
			return $image;
		}
	}
	return 0;
}

sub get_poster {
	my ( $self, $imdb_id ) = @_;
	die("You need an tmdb_key") unless $self->{tmdb_key};
	$self->{mech}->get('http://api.themoviedb.org/2.1/Movie.getImages/en/json/'.$self->{tmdb_key}.'/'.$imdb_id);
	if ($self->{mech}->success) {
		my $json = JSON->new->utf8(0)->decode($self->{mech}->content);
		#return $json;
		unless($json->[0] eq "Nothing found.") {
			my $img = $json->[0]->{'posters'}[0]->{'image'}->{'url'};
			$img =~ s/w\d+/original/;
			return $img;
		}
	}
	return 0;
}

sub rawurlencode {
	my $unencoded_url = shift;
	my $url = URI::URL->new($unencoded_url);
	return $url->as_string;
}

sub isNumeric {
	my $input = shift;
	if ( $input =~ /^[\+-]?[0-9]*\.?[0-9]*$/ && $input !~ /^[\. ]*$/ ) {
		return 1;
	} else {
		return 0;
	}
}

1;