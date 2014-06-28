#!/usr/bin/perl -w
use strict;

use HTML::Element;
use HTML::TreeBuilder 5 -weak;
use HTML::Parser;


my $html = HTML::Parser->new(@ARGV);

my $elem = $html->getElementsByTagName(@ARGV);
print $elem->innerText() if ref $elem;



