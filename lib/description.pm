#!/usr/bin/perl
package description;

use strict;
use warnings;
use utf8;

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		file_path => '',
		nfo_file => '',
		manual_create_possible => 1,
	);
	
	# loop trough and set the properties to self.
	for my $property ( keys %self ) {
		if (exists $param_rh->{$property}) {
			$self{$property} = delete $param_rh->{$property};
		}
	}
	
	#my $self{desc} = "";
	if ($self{nfo_file}) {
		$self{desc} = strip_nfo($self{nfo_file});
	} elsif ($self{file_path}) { # Will try to make som mediainfo parsere here later.
		$self{desc} = manual_create() if ($self{manual_create_possible});
	} else {
		$self{desc} = manual_create() if ($self{manual_create_possible});
	}
	die("Could not create description.") if (!$self{desc} and $self{manual_create_possible});
	
	# Fallback
	$self{desc} = "NFO managler......." unless $self{desc};
	return bless \%self, $class;
}

sub strip_nfo {
	my $nfo_file = shift;
	my $ut = "";
	open(my $NFO, "<", $nfo_file) or die("Could not open NFO: ".$nfo_file);
	while(<$NFO>) {
		$ut .= $_;
	}
	close($NFO);
	$ut =~ s/[^a-z0-9\s\(\)\[\]\-_\.*:\/]//gi; # remove everything but..
	$ut =~ s/^[\t\f ]+|[\t\f ]+$//mg; # trim each line
	$ut =~ s/\n(?:\s*\n)+/\n/g; # remove blank lines
	$ut =~ s/([a-vx-z])\1{2,}//gi; # remove repeating chars
	return '[pre]'.$ut.'[/pre]';
}

sub manual_create {
	print "Type in description, end width ^D (CTRL+D):\n";
	my @desc = <STDIN>;
	my $descr = "";
	foreach (@desc) { $descr .= $_ }
	return $descr;
}

1;