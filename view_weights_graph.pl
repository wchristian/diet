#!/usr/bin/perl

use 5.010;
use lib ('.');

use CGI::Carp qw(fatalsToBrowser);
use strict;
use CGI;
use DBI;
use GD::Graph::mixed;
use Time::localtime;
use Config::Simple;
use DateTime;
use POSIX qw(ceil floor);
use EMA 'get_balanced_ema';

my $query = new CGI;
#'2008/11/27'
my $stop_dt  = ( string_to_dt( undef or $query->param( 'stop_date'  ) ) or DateTime->now->set( hour   => 0, minute => 0, second => 0,) );
my $start_dt = ( string_to_dt( undef or $query->param( 'start_date' ) ) or $stop_dt->clone->subtract( days => 30 ) );
my $days = $start_dt->delta_days( $stop_dt )->{days};
my $prev_dt  = $start_dt->clone->subtract( days => $days );


my $ini = "config.pl";
( -f "$ini" ) or die "Can't open initialization file '$ini', $!\n";

my $cfg = new Config::Simple( $ini );
my $username = $cfg->param( "mysqluser" );
my $password = $cfg->param( "mysqlpasswd" );
my $database = $cfg->param( "database" );
my $host = $cfg->param( "dbserver" );
my $prefix = $cfg->param( "dbprefix" );
my $moving_avg_pts = $cfg->param( "moving_avg_pts" );
my $target_weight = $cfg->param( "target_weight" );
my $weight_in = $cfg->param( "weight_in" );
my $start_yr = $cfg->param( "start_yr" );
my $start_month = $cfg->param( "start_month" );
my $start_day = $cfg->param( "start_day" );
my @clrs=( 'gray', 'gray', 'lred', undef, 'lblue', 'lyellow' );

sub string_to_dt {
   my ($string) = @_;
   
   my $dt;
   if ( $string =~ m!^([0-9]{4,4})/([0-9]{1,2})/([0-9]{1,2})$! ) {
      $dt = DateTime->new( year   => $1,
                        month  => $2,
                        day    => $3,
                      );
   }
   
   return $dt;
}

my @dates = ();
my @weights = ();

my $y_min_value = 999;
my $y_max_value = 0;

#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile","","");

my $sql_statement = "SELECT date, weight FROM ${prefix}weights WHERE date >= ? AND date <= ? ORDER BY date DESC";
my $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( $prev_dt->ymd('/'), $stop_dt->ymd('/') ) or die "Could not execute: " . $dbh->errstr();

my $last_dt = $stop_dt->clone; 
my $first_dt;
$last_dt->add( days => 1 );
while( my @ary = $sth->fetchrow_array() ) {
    my $curr_dt = string_to_dt( $ary[0] );
   
    my $delta = $curr_dt->delta_days($last_dt)->delta_days - 1;
    for ( ('') x $delta ) {
        $last_dt->subtract( days => 1 );
        $first_dt ||= string_to_dt( $last_dt->ymd('/') );
        unshift( @dates, substr( $last_dt->ymd('/'), 8 ) );
        unshift( @weights, undef );
    } 
    
    $first_dt ||= string_to_dt( $ary[0] );
    unshift( @dates, substr( $ary[0], 8 ) );
    unshift( @weights, $ary[1] );
    $last_dt = $curr_dt;
}

while ( $prev_dt < $last_dt ) {
   unshift( @dates, substr( $last_dt->ymd('/'), 8 ) );
   unshift( @weights, undef );
   $last_dt->subtract( days => 1 );
}

while ( $first_dt < $stop_dt ) {
   $first_dt->add( days => 1 );
   push  @dates, substr( $first_dt->ymd('/'), 8 );
}

my $avg_size = 14;
my $weight_exponent = 0.86;
my @avg = get_balanced_ema( $avg_size, $weight_exponent, @weights );

my @change = ( 0 );
$change[$_] = $avg[$_] - $avg[$_ - 1] for ( 1 .. $#avg );

my @change_trend = get_balanced_ema( $avg_size, $weight_exponent, @change );


splice( @dates, 0, $days );
splice( @weights, 0, $days );
splice( @change, 0, $days );
splice( @change_trend, 0, $days );
splice( @avg, 0, $days );

my $plan_start_dt = string_to_dt( "2008/11/26" );
my $plan_stop_dt = string_to_dt( "2009/11/18" );
my $plan_days = $plan_start_dt->delta_days( $plan_stop_dt )->{days};
my $start_weight = 107.9;
my $weight_diff = $start_weight-$target_weight;
my $daily_weight_diff = $weight_diff/$plan_days;

my $days_to_start = $plan_start_dt->delta_days( $start_dt )->{days}-2;
$days_to_start *= -1 if $start_dt < $plan_start_dt;
my $left_weight = $start_weight - ($daily_weight_diff * $days_to_start);
my $right_weight = $left_weight - ($daily_weight_diff * (@weights-4));

my @plan;
=cut
$plan[0] = $left_weight;
$plan[$#weights] = $right_weight;

for my $point ( 0..$#plan ) {
   last if $plan[$point] <= $start_weight;
   
   $plan[$point+1] = $plan[$point]-$daily_weight_diff;
   $plan[$point] = undef;
}
=cut

my $weight_change = sprintf ( "%.3f", $avg[$#avg]-$avg[0] );
my $weekly_weight_change = sprintf ( "%.3f", $weight_change / $days * 7 );

my $kcal_per_kg = 6800;

my $cal_diff = int $weight_change * $kcal_per_kg;
my $daily_cal_diff = int $cal_diff / $days;

my $weight_type = 'gain';
if ( $weight_change < 0 ) {
   $weight_type = 'loss';
   $weight_change *= -1;
   $weekly_weight_change *= -1;
}

my $cal_type = 'excess';
if ( $cal_diff < 0 ) {
   $cal_type = 'deficit';
   $cal_diff *= -1;
   $daily_cal_diff *= -1;
}

my @target;
$target[0] = $target_weight;
$target[$#avg] = $target_weight;


for my $array ( ( \@weights, \@avg, \@plan ) ) {
   for my $val ( @{$array} ) {
      next if (!$val);
      $y_min_value = $y_min_value < $val ? $y_min_value : $val;
      $y_max_value = $y_max_value > $val ? $y_max_value : $val;
   }
}

my $graph_spread = $y_max_value - $y_min_value;

#$y_min_value -= $graph_spread * 0.05;
#$y_max_value += $graph_spread * 0.05;

$y_min_value = floor ($y_min_value);
$y_max_value = ceil ($y_max_value);

for my $change ( @change_trend ) {
    $change *= 10;
    $change += $y_max_value;
}

my $graph = GD::Graph::mixed->new( 400, 200 );
my @legend_keys = ( undef, undef,
                   "Weekly $weight_type: $weekly_weight_change kg - Daily $cal_type: $daily_cal_diff calories",
                   "Whole $weight_type: $weight_change kg - Whole $cal_type: $cal_diff calories");
$graph->set_legend( @legend_keys );
$graph->set(
#   x_label => "Date - $days days",
   y_label => "Weight in $weight_in",
   y_tick_number => ($y_max_value - $y_min_value),
   y_min_value => $y_min_value,
   y_max_value => $y_max_value,
   title => "Weight (". $start_dt->ymd('/') ." - ". $stop_dt->ymd('/') .")",
   values_vertical => 1,
   x_label_skip => 7,
   long_ticks => 1,
   x_tick_offset => 7-$start_dt->{local_c}->{day_of_week}+1,
   dclrs => [ @clrs ],
   types => [qw(lines points lines)],
   markers => [6],
   marker_size => 2,
   boxclr => "lgray",
   line_width => 2,
) or warn( $graph->error );

print $query->header( -type => "image/png" );
my @data = ( \@dates, \@change_trend, \@weights, \@avg, [], \@target, \@plan );
my $image = $graph->plot( \@data ) or die( $graph->error );
print $image->png();


##############################################################################
1;
__END__

=pod

=head1 NAME

Diet Tracker - view_weights_graph.pl

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

