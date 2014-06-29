#!/usr/bin/perl -w
use strict;

use HTML::TagParser;

if ( $#ARGV == 1 )
{

	my $html = HTML::TagParser->new($ARGV[0]);
	my $elem = $html->getElementsByTagName($ARGV[1]);
	print $elem->innerText() if ref $elem;

}
else
{
	print "Usage: getelement [file] [tag]\n";
}





