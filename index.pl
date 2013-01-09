#!/usr/bin/perl

use lib ('./lib');

use strict;

use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Time::localtime;
use Date::Calc qw(Delta_Days);
use HTML::Entities;
use HTML::Template;
use Config::Simple;

my $ini = "config.pl";
( -f "$ini" ) || die "Can't open initialization file '$ini', $!\n";

my $cfg = new Config::Simple( $ini );
my $username = $cfg->param( "mysqluser" );
my $password = $cfg->param( "mysqlpasswd" );
my $database = $cfg->param( "database" );
my $host = $cfg->param( "dbserver" );
my $prefix = $cfg->param( "dbprefix" );
my $en_autosuggest = $cfg->param( "en_autosuggest" );
my $max_intake = $cfg->param( "max_intake" );
my $weight_in = $cfg->param( "weight_in" );
my $height = $cfg->param( "height" );
my $vacation = $cfg->param( "vacation" );
my $start_yr = $cfg->param( "start_yr" );
my $start_month = $cfg->param( "start_month" );
my $start_day = $cfg->param( "start_day" );
my $target_weight = $cfg->param( "target_weight" );

my $tm = localtime;
my ($DAY, $MONTH, $YEAR) = ($tm->mday, ($tm->mon)+1, $tm->year+1900);
my $today = sprintf( "%04d/%02d/%02d", $YEAR, $MONTH, $DAY );
my @now = ($YEAR, $MONTH, $DAY);
my $start_date = sprintf( "%04d/%02d/%02d", $start_yr, $start_month, $start_day );
my @start = ($start_yr, $start_month, $start_day);
my $difference = Delta_Days(@start, @now) + 1 - $vacation;

#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile","","");





my $sql_statement = "SELECT item, kcal, amount FROM ${prefix}foods WHERE date = ?";
my $sth;
unless ( $sth = $dbh->prepare( $sql_statement ) ) {
   my $sth2 = $dbh->prepare( "  CREATE TABLE `dt_foods` (
     `id` INTEGER PRIMARY KEY,
     `date` date default NULL,
     `item` varchar(50) default NULL,
     `kcal` INTEGER default NULL,
      `protein` REAL DEFAULT '0' NOT NULL,
      `carb` REAL DEFAULT '0' NOT NULL,
      `fat` REAL DEFAULT '0' NOT NULL,
      `amount` INTEGER DEFAULT '100' NOT NULL
   );  " ) or die "Table did not exist and could not be created: " . $dbh->errstr();
   $sth2->execute() or die "Could not execute: " . $dbh->errstr();
   $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
}
$sth->execute( $today ) or die "Could not execute: " . $dbh->errstr();
my ($item, $intake, $today_intake, $total_intake, $intake_diff, $avg_intake, $amount);
$sth->bind_columns( undef, \$item, \$intake ,\$amount);

my @today_in_loop;
$today_intake=0;

while( $sth->fetch() ) {
   $today_intake = $today_intake + ($intake * $amount / 100);
   my %row;
   %row = (
      item => encode_entities( $item ),
      calorie => ($intake * $amount / 100),
   );
   push(@today_in_loop,\%row);
}
$intake_diff = $max_intake - $today_intake;


$sql_statement = "SELECT SUM(kcal * amount / 100) FROM ${prefix}foods WHERE date >= ?";
$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( "$start_yr/$start_month/$start_day" ) or die "Could not execute: " . $dbh->errstr();
$sth->bind_columns( undef, \$total_intake );
while($sth->fetch()) {
	$avg_intake = sprintf( "%3.0f", $total_intake / $difference );
}

my $current_weight = 0;
my $current_weight_date = "";
my $start_weight = 0;
my $weight_remaining = 0;
my $weight_diff = 0;
my $weight_movement = '';

$sql_statement = "SELECT date, trend FROM ${prefix}weights WHERE date >= ? ORDER BY date DESC LIMIT 1";
unless ( $sth = $dbh->prepare( $sql_statement ) ) {
   my $sth2 = $dbh->prepare( "CREATE TABLE `dt_weights` (
  `id` INTEGER PRIMARY KEY,
  `date` date NOT NULL UNIQUE default '0000-00-00',
  `weight` NUMERIC(5,2) default NULL,
  `trend` NUMERIC(5,2) default NULL
); " ) or die "Table did not exist and could not be created: " . $dbh->errstr();
   $sth2->execute() or die "Could not execute: " . $dbh->errstr();
   $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
}
$sth->execute( $start_date ) or die "Could not execute: " . $dbh->errstr();
$sth->bind_columns( undef, \$current_weight_date, \$current_weight );
while( $sth->fetch() ) {
	$current_weight_date = $current_weight_date ? $current_weight_date : 0;
	$current_weight = $current_weight ? $current_weight : 0;
	$weight_remaining = sprintf( "%.01f", ( $current_weight - $target_weight ) );

    my $max_intake = (66+(13.7 *$current_weight)+(5 *165) - (6.8 *25))*1.2;
    $max_intake *= 0.75;
    $intake_diff = $max_intake - $today_intake;
}

$sql_statement = "SELECT trend FROM ${prefix}weights WHERE date >= ? ORDER BY date ASC LIMIT 1";
$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( $start_date ) or die "Could not execute: " . $dbh->errstr();
$sth->bind_columns( undef, \$start_weight );
while( $sth->fetch() ) {
	$start_weight = $start_weight ? $start_weight : 0;
	$weight_diff = sprintf( "%.01f", ( $start_weight - $current_weight ) );
}


$sql_statement = "SELECT * FROM ${prefix}lifting LIMIT 1";
unless ( $sth = $dbh->prepare( $sql_statement ) ) {
   my $sth2 = $dbh->prepare( "CREATE TABLE `dt_lifting` (
  `id` INTEGER PRIMARY KEY,
  `date` TEXT NOT NULL default '0000-00-00',
  `weight` REAL NOT NULL default 0,
  `type` TEXT NOT NULL default 'none'
); " ) or die "Table did not exist and could not be created: " . $dbh->errstr();
   $sth2->execute() or die "Could not execute: " . $dbh->errstr();
   $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
}




$sth->finish();
$dbh->disconnect();

$weight_movement = ($weight_diff > 0) ? 'down.gif' : 'up.gif';
$weight_movement = 'expand.png' if ($weight_diff==0);

my $bmi_weight = 0;

if( $weight_in eq 'Kg' ) {
   $bmi_weight = &convert_to_pounds( $current_weight );
}
else {
   $bmi_weight = $current_weight;
}

my $bmi = 'undefined';

if( $bmi_weight != 0 ) {
	my $bmi_height = &convert_to_inches( $height );
	$bmi = sprintf( "%.01f", ( $bmi_weight / ( $bmi_height * $bmi_height ) ) * 703 );
}

my $bmi_cat='';

if( $bmi > 29.9 ) {
	$bmi_cat = 'Obesity (&gt; 29.9)';
}
elsif ( $bmi <= 29.9 && $bmi >= 25.0 ) {
	$bmi_cat = 'Overweight (25.0 - 29.9)';
}
elsif ( $bmi <= 24.9 && $bmi >= 18.5 ) {
	$bmi_cat = 'Healthy (18.5 - 24.9)';
}
else {
	$bmi_cat = 'Underweight (&lt; 18.5)';
}

if( $bmi eq 'undefined' ) {
	$bmi_cat='';
}

my $template = HTML::Template->new( filename => 'tmpl/index.tmpl' );

$template->param( today_in_loop => \@today_in_loop );
$template->param( en_autosuggest => $en_autosuggest );
$template->param( days => $difference );
$template->param( today_intake => $today_intake );
$template->param( intake_diff => int $intake_diff );
$template->param( start_date => $start_date );
$template->param( current_date => $today );
$template->param( weight_in => $weight_in );
$template->param( avg_intake => $avg_intake );
$template->param( bmi => $bmi );
$template->param( bmi_cat => $bmi_cat );
$template->param( weight_date => $current_weight_date );
$template->param( weight_remaining => $weight_remaining );
$template->param( weight_diff => abs($weight_diff) );
$template->param( weight_movement => $weight_movement );
$template->param( start_year => $start_yr );
$template->param( current_year => $YEAR );

print "Content-Type: text/html;charset=iso-8859-1\n\n";
print $template->output;

sub convert_to_pounds {
	my($kilos) = $_[0];
 	my($pounds) = $kilos * 2.20462262;
 	return $pounds;
}

sub convert_to_inches {
 	my($centimeters) = $_[0];
 	my($inches) = $centimeters * 0.393700787;
 	return $inches;
}

##############################################################################
1;
__END__

=pod

=head1 NAME

Diet Tracker - index.pl

=head1 AUTHORS

Srijith K. Nair E<lt>srijith[at]srijith.netE<gt> &
Kyle Farnung E<lt>kyle[at]kylefarnung.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2008  Srijith K. Nair, Kyle Farnung

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
