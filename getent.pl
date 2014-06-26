#!/usr/bin/env perl
# converts an html/xml-compliant string to it's unincoded (UTF-8)
# WYSIQYG form. Since qthelpgenerator does not understand some of
# the entities used in the boost docs, we must decode them. This
# may not be a problem for items like &amp; or &gt; (&lt;) or even
# &nbsp; but it IS a problem for nonstandard ones like &#160;
# which is only supported by SOME browsers. To ensure stability
# this script was written to accomodate this problem. 

use HTML::Entities;

$num_args = $#ARGV + 1;
if ($num_args != 1) 
{
  print "\nUsage: getent.pl [html-encoded string] \n";
  exit;
}

$encoded=$ARGV[0];
$decoded=decode_entities($encoded);
print($decoded);


