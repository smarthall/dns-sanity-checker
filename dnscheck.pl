#!/usr/bin/perl -w

use Net::DNS::Resolver::Recurse;
use Data::Dumper;
use 5.010001;

# Configuration
my $domain = "realestate.com.au";
my $host = "partner";
my @validips = ("203.17.253.19", "195.43.154.19");

# Code


###### Fetch data from the authorative NS ######
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

###### Process the data ######
my @emptyns = ();
my %invalidip = ();

# Check each nameserver
foreach my $ns (keys %answers) {
  my @ips = @{$answers{$ns}};

  if (scalar(@ips) == 0) {
    push @emptyns, $ns
  }

  foreach my $ip (@ips) {
    if ( grep $_ eq $ip, @validips ) {
      $invalidip{$ns} = $ip;
    }
  }
}

###### Tell nagios ######
my $rtrncode = 0;
my $status = '';
my $extsstatus = '';

if (scalar(@emptyns) > 0) {
  $rtrncode = 2;
  $extstatus .= 'Nameservers sending empty results: ' . join(', ', @emptyns) . " ";
}

if (scalar(keys %invalidip) > 0) {
  $rtrncode = 2;
  $extstatus .= 'Nameservers sending invalid IP addresses: ' . join(', ', %invalidip) . " ";
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

print "$status|$extstatus";
exit $rtrncode;

