#!/usr/bin/perl

use strict;
use warnings;

# Only under development
use Data::Dumper;

use lib './lib';
use nb;

my $nb = nb->new( {
	url => 'https://site.net',
	username => 'whut',
	password => 'dsa',
	fastresume => 0,
	logging => 1,
} );

#$nb->upload();

#my $uri = $nb->download('fsa');
#print $uri."\n";

#print Dumper($nb);
#my $test = $nb->test('test', 'test2');
#print Dumper($test);

#print "wut: ".$nb->login()."\n";
#print "hvafan\n";