#!/usr/bin/perl -w
use Expenses;
use CGI;

binmode(STDOUT, ":encoding(utf-8)");


my $cgi = CGI->new();
$cgi->charset('utf-8');


my $webapp = Expenses->new(QUERY => $cgi);
$webapp->run()
