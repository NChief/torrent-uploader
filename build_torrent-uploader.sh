#!/bin/bash
# build script for torrent-uploader.pl
# This will install all modules etc for the script to run

set -e

if ! which apt-get &> /dev/null; then
        echo "This script is only for users of debian or distros with based on debian(like ubuntu)";
fi

if [ "$(whoami)" != 'root' ]; then
        echo "You need to run $0 as a root user."
        #exit 1;
fi

echo "Checking for needed packages.."

if ! which perl &> /dev/null; then
        echo "Perl not found, installing.."
        apt-get -y install perl
fi

if [ "$(dpkg-query -W -f='${Status}\n' perlmagick)" != "install ok installed" ]; then
        echo "perlmagick not found, installing.."
        apt-get -y install perlmagick
fi

if ! which git &> /dev/null; then
        echo "git not found, installing..:"
        apt-get -y install git-core
fi

if ! which make &> /dev/null; then
        echo "make not found, installing..:"
        apt-get -y install make
fi

if ! which aclocal &> /dev/null; then
        echo "automake not found, installing..:"
        apt-get -y install automake
fi

if ! which gcc &> /dev/null; then
        echo "gcc not found, installing..:"
        apt-get -y install gcc
fi


buildtorrent="$(buildtorrent -V | grep buildtorrent | cut -d" " -f2 | cut -d~ -f1)"
if [ "$buildtorrent" != "0.9" ] && [ "$buildtorrent" != "0.8" ]; then
        if which buildtorrent &> /dev/null; then # Do I need this?
                echo "Your buildtorrent is too old. Deleting old buildtorrent..:"
                apt-get -y purge buildtorrent
        else
                echo "buildtorrent not installed."
        fi
        echo "Installing buildtorrent..:"
        git clone git://gitorious.org/buildtorrent/buildtorrent.git
        cd buildtorrent
        aclocal
        autoconf
        autoheader
        automake -a -c
        ./configure
        make
        make install
        cd ..
fi

#exit 0

echo "Checking for needed perl modules.."

modules=( "WWW::Mechanize" "File::Basename" "Getopt::Long" "File::Find" "Config::Simple" "Convert::Bencode" "Log::Log4perl" "URI::URL" "Cwd" "utf8" "Image::Thumbnail" "Image::Imgur" "XML::Simple" "JSON" "File::Copy" "IO::Socket::SSL" "LWP::Protocol::https" )

for i in "${modules[@]}"; do
        if ! perl -m$i -e 0 &> /dev/null; then
                echo "$i not found, installing.."
                env PERL_MM_USE_DEFAULT=1 cpan -f $i
        fi
done

apt-get -y install libdatetime-perl

echo "DONE!"

