#!/usr/bin/perl -w

use 5.010001;
use Net::DNS::Resolver::Recurse;
use Getopt::Long;
use Data::Dumper;

# Configuration
my $domain = '';
my $host = '';
my $ipstring = '';

###### Fetch config from command line ######
my $cmdline = GetOptions ("domain|zone=s"   => \$domain,
                          "record|property|host=s"   => \$host,
                          "validips|ip|iplist=s" => \$ipstring);

if (($domain eq '') || ($host eq '') || ($ipstring eq '')) {
  print "Please provide a domain, host and list of valid ips\n";
  print "Example: ./dnscheck.pl --domain danielhall.me --record mail --validips 106.187.99.154\n";
  exit 2;
}

my @validips = split(/,/, $ipstring);

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
  if (defined $answer) {
    foreach my $ip ($answer->answer) {
      push ($answers{$ns->nsdname}, $ip->address);
    }
  }
}

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
    if ( !($ip ~~ @validips) ) {
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

