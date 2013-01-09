#!/usr/bin/perl -w

use Net::DNS::Resolver::Recurse;
use Data::Dumper;

my $domain = "realestate.com.au";
my $host = "partner";
my @validips = ("203.17.253.19", "195.43.154.19")

my $fqdn = $host . "." . $domain;


my $pres = Net::DNS::Resolver->new;
$pres->tcp_timeout(2);
$pres->udp_timeout(2);
$pres->debug(0);
 
my $packet = $pres->query($domain, "NS");

foreach my $ns ($packet->answer) {
  print "Checking: " . $ns->nsdname . "\n";
  $pres->nameservers($ns->nsdname);
  $answer = $pres->query($fqdn, "A");
  foreach my $ip ($answer->answer) {
    print "Got IP: " . $ip->address . "\n";
  }
}
