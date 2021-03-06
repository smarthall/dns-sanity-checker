#!/usr/bin/perl -w
# nagios: -epn
##########################################################################
# Name:     DNS Sanity Checker
# Author:   Daniel Hall <daniel@danielhall.me>
# License:  GPLv3+
# URL:      https://github.com/smarthall/dns-sanity-checker
# Description:
#  DNS Sanity check is designed to check that DNS RR or A records are
#  being correctly served by all the authorative nameservers. It does
#  this by first asking for the list of authorities, then checking that
#  each one returns results, and that there are no invalid ips.
#
# TODO:
#  - Accept address ranges as valid ips
#  - If no valid ip list is given, only check for empty results
#  - Support CNAME and MX records
#  - Different output formats, not just Nagios
#
##########################################################################

use 5.010000;
use Net::DNS::Resolver::Recurse;
use Getopt::Long;
use Data::Dumper;

# Configuration
my $domain = '';
my $host = '';
my $ipstring = '';
my $verbose = '';

###### Fetch config from command line ######
my $cmdline = GetOptions ("domain|zone=s"   => \$domain,
                          "record|property|host=s"   => \$host,
                          "validips|ip|iplist=s" => \$ipstring,
                          "verbose" => \$verbose);

if (($domain eq '') || ($host eq '') || ($ipstring eq '')) {
  print "Please provide a domain, host and list of valid ips\n";
  print "Example: ./dnscheck.pl --domain danielhall.me --record mail --validips 106.187.99.154\n";
  exit 2;
}

my @validips = split(/,/, $ipstring);
my $unknown = 0;

###### Fetch data from the authorative NS ######
my $fqdn = $host . "." . $domain;

my $pres = Net::DNS::Resolver->new;
$pres->tcp_timeout(2);
$pres->udp_timeout(2);
if ($verbose) {
  $pres->debug(1);
} else {
  $pres->debug(0);
}
 
my $packet = $pres->query($domain, "NS");

my %answers = ();
foreach my $ns ($packet->answer) {
  if ($verbose) {print "**** Checking " . $ns->nsdname . "\n"};
  $pres->nameservers($ns->nsdname);
  $answer = $pres->send($fqdn, "A");
  $answers{$ns->nsdname} = [];
  if (defined $answer) {
    foreach my $ip ($answer->answer) {
      push (@{$answers{$ns->nsdname}}, $ip->address);
    }
  } else {
    $unknown = 1;
  }
}

###### Process the data ######
my @emptyns = ();
my %invalidip = ();

# Check each nameserver
foreach my $ns (keys %answers) {
  if ($verbose) {print "**** Processing $ns\n"};
  my @ips = @{$answers{$ns}};

  if (scalar(@ips) == 0) {
    if ($verbose) {print "**** Nameserver $ns had no results\n"};
    push @emptyns, $ns
  }

  foreach my $ip (@ips) {
    if ( !($ip ~~ @validips) ) {
      if ($verbose) {print "**** Nameserver $ns sent an invalid IP of $ip\n"};
      $invalidip{$ns} = $ip;
    }
  }
}

###### Tell nagios ######
my $rtrncode = 0;
my $status = '';
my $extstatus = '';

if (scalar(@emptyns) > 0) {
  $rtrncode = 2;
  $extstatus .= 'Nameservers sending empty results: ' . join(', ', @emptyns) . " ";
}

if (scalar(keys %invalidip) > 0) {
  $rtrncode = 2;
  $extstatus .= 'Nameservers sending invalid IP addresses: ' . join(', ', %invalidip) . " ";
}

if ($unknown == 1) {
  $rtrncode = 3;
}

if ($rtrncode == 0) {
  $status = 'NS OK - All authorative nameservers correct';
} elsif ($rtrncode == 1) {
  $status = 'NS WARNING - Something is slightly wrong';
} elsif ($rtrncode == 2) {
  $status = 'NS CRITICAL - One or more nameservers are sending incorrect results';
} elsif ($rtrncode == 3) {
  $status = 'NS UNKNOWN - Something is preventing the check from checking';
}

print "$status|$extstatus\n";
exit $rtrncode;

