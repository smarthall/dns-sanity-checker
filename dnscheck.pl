#!/usr/bin/perl -w

use Net::DNS::Resolver::Recurse;
use Data::Dumper;
use 5.010001;

# Configuration
my $domain = "realestate.com.au";
my $host = "partner";
my @validips = ("203.17.253.19", "195.43.154.19");

# Code
my $fqdn = $host . "." . $domain;

my $pres = Net::DNS::Resolver->new;
$pres->tcp_timeout(2);
$pres->udp_timeout(2);
$pres->debug(0);
 
my $packet = $pres->query($domain, "NS");

my %answers = ();
foreach my $ns ($packet->answer) {
  $pres->nameservers($ns->nsdname);
  $answer = $pres->query($fqdn, "A");
  $answers{$ns->nsdname} = [];
  foreach my $ip ($answer->answer) {
    push ($answers{$ns->nsdname}, $ip->address);
  }
}

print Dumper(\%answers);



