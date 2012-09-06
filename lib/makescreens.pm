#!/usr/bin/perl
package makescreens;

use strict;
use warnings;

use Image::Thumbnail;
use Image::Imgur;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

sub new {
	my ($class, $param_rh ) = @_;
	
	my %self = (
		mediafile => '',
		imgur_key => '',
    ihack_keys => [''],
    ib_keys => {
      api_key => '',
      api_secret => '',
      o_token => '',
      o_token_secret => '',
    },
		ss => 60,
		dir => './',
    imghost => 'imgur',
	);
	
	# loop trough and set the properties to self.
	for my $property ( keys %self ) {
		if (exists $param_rh->{$property}) {
			$self{$property} = delete $param_rh->{$property};
		}
	}
	
	#die("info missing") unless ($self{mediafile} and $self{imgur_key});
  die("imghost missing or invalid") unless ($self{imghost} =~ /^(imgur|imagebam|imageshack)$/);
	
	#print 'mplayer -ss '.$self{ss}.' -vo png:z=9:outdir="'.$self{dir}.'" -ao null -frames 2 "' . $self{mediafile} . '" > /dev/null 2>&1';
	system('mplayer -ss '.$self{ss}.' -vo png:z=9:outdir="'.$self{dir}.'" -ao null -frames 2 "' . $self{mediafile} . '" > /dev/null 2>&1') == 0 or die("unable to make screen of ".$self{mediafile});
	
  my $img;
  my $file = '00000002.png';
  if ($self{'imghost'} eq 'imgur') {
    $img = imgur($file, %self);
  } elsif ($self{'imghost'} eq 'imagebam') {
    $img = ib($file, 0, %self);
  } elsif ($self{'imghost'} eq 'imageshack') {
    $img = ihack($file, %self);
  }
	return bless \%self, $class unless $img;
  
  $self{screen} = $img;
  
	my $t1 = new Image::Thumbnail(
		size       => 300,
		create     => 1,
		input      => $self{dir}.'00000002.png',
		outputpath => $self{dir}.'thumb.png'
	);
  
  my $thumb;
  $file = 'thumb.png';
  if ($self{'imghost'} eq 'imgur') {
    $thumb = imgur($file, %self);
  } elsif ($self{'imghost'} eq 'imagebam') {
    $thumb = ib($file, 1, %self);
  } elsif ($self{'imghost'} eq 'imageshack') {
    $thumb = ihack($file, %self);
  }
	return bless \%self, $class unless $thumb;
  
  $self{thumb} = $thumb;
  
	unlink($self{dir}."00000001.png", $self{dir}."00000002.png", $self{dir}."thumb.png");
	
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
	print $err."\n";
}

# Upload with imgur
sub imgur {
  my ($file, %self) = @_;
  my $imgur = new Image::Imgur(key => $self{imgur_key});
	my $img = $imgur->upload($self{dir}.$file);
	if (isNumeric($img)) {
		err("Upload to imgur failed with code: ".$img, $self{dir});
		return 0;
	}
  return $img;
}

# Upload with imageshack
sub ihack {
  my ($file, %self) = @_;
  
  #print Dumper($self{'ihack_keys'});
  my @api_keys = @{$self{'ihack_keys'}};
  
  my $userAgent = LWP::UserAgent->new();
  foreach my $key (@api_keys) {
    my $request = POST 'http://www.imageshack.us/upload_api.php', 
      Content_Type => 'form-data', 
      Content => [fileupload => [$self{dir}.$file],
        xml => 'yes', 
        key => $key
      ];
    my $response = $userAgent->request($request);
    if($response->decoded_content =~ /<image_link>(.+?)<\/image_link>/) {
      return $1;
    } #else {
      #die("Could not upload to imageshack\n ".$response->decoded_content);
    #}
  }
  err("Could not upload to imageshack", $self{dir});
  return 0;
}

# Upload with imagebam
sub ib {
  my ($file, $tmb, %self) = @_;
  
  my $API_KEY = $self{'ib_keys'}{'api_key'};
  my $API_SECRET = $self{'ib_keys'}{'api_secret'};
  my $o_token = $self{'ib_keys'}{'o_token'};
  my $o_token_secret = $self{'ib_keys'}{'o_token_secret'};
  
  my $o_timestamp = time;
  my $o_sig_method = 'MD5';
  my $o_nonce = nonce();
  
  my $o_sig_string = $API_KEY . $API_SECRET . $o_timestamp . $o_nonce . $o_token . $o_token_secret;
  my $o_sig = md5_hex($o_sig_string);
  
  my $userAgent = LWP::UserAgent->new();
  #$userAgent->agent('Opera/9.80 (Windows NT 6.1; Win64; x64; U; nb) Presto/2.10.289 Version/12.01');
  my $request = POST 'http://www.imagebam.com/sys/API/resource/upload_image', 
    Content_Type => 'form-data', 
    Content => [
      oauth_consumer_key => $API_KEY,
      oauth_signature_method => $o_sig_method,
      oauth_signature => $o_sig,
      oauth_timestamp => $o_timestamp,
      oauth_nonce => $o_nonce,
      oauth_token => $o_token,
      image => [$file],
      content_type => "family",
      thumb_size => '180x180',
      thumb_cropping => 0,
    ];
  my $response = $userAgent->request($request);
  
  #print $response->decoded_content;
  my $json = decode_json($response->decoded_content);
  #print "yy\n";
  if(defined($json->{rsp}->{status}) and $json->{rsp}->{status} eq 'ok') {
    my $url = $json->{rsp}->{image}->{URL};
    my $name = $json->{rsp}->{image}->{filename};
    
    return $url unless($tmb);
    
    my $res = $userAgent->get($url);
    if($res->decoded_content =~ /'(http:\/\/.+\Q${name}\E)'/) {
      return $1;
    } else {
      err("Could not upload to imagebam! 1");
    }
  } else {
    err("could not upload to imagebam!");
  }
  return 0;
}

sub nonce {
  my @a = ('A'..'Z', 'a'..'z', 0..9);
  my $nonce = '';
  for(0..31) {
    $nonce .= $a[rand(scalar(@a))];
  }
  $nonce;
}

1;