#!/usr/bin/env perl
# strip out &entities; from XML-encoded text with >=HTML4 defined entities
# we dont really validate it, just strip them out as they are mostly non-breaking
# spaces (ie, &#160; (XML) or &nbsp; (HTML-compliant XML, ka just "HTML") ) 
# any other > &#128 is converted to spaces as well. If you are using a different
# language you can disable this by just uncommenting the first 2 lines but for english
# versions it looks much cleaner in QTC/QA this way. Please note that unencoding to
# strings and not checking for the  >128 will cause the XML to become invalid, so
# everything converted to space is then converted to &nbsp; which is generally 
# accepted by QTC/QA as well.

# If you dont want this feature, do this to the next block:
# - comment-out the first line (just for speed up)
# - uncomment the second line (to disable script's HTML string decoding)

use HTML::Entities;
#my $disabledecode=1;



$num_args = $#ARGV + 1;
if ($num_args != 1) 
{
  print "\nUsage: getent.pl [html-encoded string] \n";
  exit;
}
$encoded=$ARGV[0];
if ($disabledecode == 1)
{
	print $encoded;
}
else
{
	$decoded=decode_entities($encoded);
	my $result="";
	for (my $i=0; $i < length($decoded); $i++)
	{	
		my $char = substr($decoded,$i,1);
		my $asc = ord($char);
		if ( $asc >= 129 || $asc < 33 ) # usually a nbsp, just turn to space
		{
			$result .= "&nbsp;";
		}
		else
		{
			$result .= $char;
		}		
	}
	if ( length($result) == 0 )
	{ 
		print "untitled"; 
	}
	else
	{ 
		print $result; 
	}
}
