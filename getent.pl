#!/usr/bin/perl
use HTML::Entities;
$num_args = $#ARGV + 1;
if ($num_args != 1) 
{
  print "\nUsage: getent.pl [html-encoded string] \n";
  exit;
}
$encoded=$ARGV[0];
$decoded=decode_entities($encoded);
$rencoded=encode_entities($decoded);
print $rencoded;

