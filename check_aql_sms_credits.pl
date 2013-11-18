#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2010-06-17 12:08:28 +0100 (Thu, 17 Jun 2010)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check the remaining AQL SMS credits on an account for Nagios SMS Alerting";

# Credit to my ex-colleague Richard Harvey @ Specific Media for coming up with this idea
#
# This is a complete reimplementation of that idea using my personal library for improved code quality, error handling, perfdata

$VERSION = "0.5";

use strict;
use warnings;
use SMS::AQL;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;

my $aql_user;
my $aql_password;

%options = (
    "u|user=s"          => [ \$aql_user,     "AQL account user. Use \$AQL_USERNAME environment variable instead to prevent this showing on the process list" ],
    "p|password=s"      => [ \$aql_password, "AQL account password. Use \$AQL_PASSWORD environment variable instead to prevent this showing on the process list" ],
    "w|warning=s"       => [ \$warning,      "Warning threshold or ran:ge (inclusive)"  ],
    "c|critical=s"      => [ \$critical,     "Critical threshold or ran:ge (inclusive)" ],
);

if(defined($ENV{"AQL_USERNAME"})){
    $aql_user = $ENV{"AQL_USERNAME"};
}
if(defined($ENV{"AQL_USER"})){
    $aql_user = $ENV{"AQL_USER"};
}
if(defined($ENV{"AQL_PASSWORD"})){
    $aql_password = $ENV{"AQL_PASSWORD"};
}

get_options;
$aql_user     = validate_user($aql_user);
$aql_password = validate_password($aql_password);
validate_thresholds(1, 1, { "simple" => "lower", "integer" => 1 } );

set_timeout();

vlog2 "creating AQL instance";
my $sms = new SMS::AQL({
                        username => $aql_user,
                        password => $aql_password,
                       }) || quit "UNKNOWN", "Failed to connect to AQL: $!";
defined($sms) or quit "UNKNOWN", "failed to create AQL instance";
vlog2 "created AQL instance";
vlog2 "fetching credit number";
my $credit = $sms->credit();

unless($sms->last_status()){
    quit "UNKNOWN", "Failed to retrieve credit from AQL: " . $sms->last_response();
}

defined($credit) or quit "UNKNOWN", "Failed to fetch AQL credit number";
isInt($credit) or quit "UNKNOWN", "invalid credit '$credit' returned by AQL, not a positive integer as expected";

$status = "OK";

$msg = "$credit SMS credits";

check_thresholds($credit);

$msg .= " | 'SMS Credits'=$credit;$thresholds{warning}{lower};$thresholds{critical}{lower};0;";

vlog2;
quit $status, $msg;