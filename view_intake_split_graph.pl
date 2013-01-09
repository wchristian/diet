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
use EMA 'get_balanced_ema';
use DateTime;

my $query = new CGI;

my $stop_dt  = ( string_to_dt( $query->param( 'stop_date' ) ) or DateTime->now );
$stop_dt->set( hour   => 0, minute => 0, second => 0,);
my $start_dt = ( string_to_dt( $query->param( 'start_date' ) ) or $stop_dt->clone->subtract( days => 30 ) );
my $prev_dt  = $start_dt->clone->subtract( days => 30 );

my $ini = "config.pl";
(-f "$ini") or die "Can't open initialization file '$ini', $!\n";

my $cfg = new Config::Simple( $ini );
my $username = $cfg->param( "mysqluser" );
my $password = $cfg->param( "mysqlpasswd" );
my $database = $cfg->param( "database" );
my $host = $cfg->param( "dbserver" );
my $prefix = $cfg->param( "dbprefix" );
my $moving_avg_pts = $cfg->param( "moving_avg_pts" );
my $max_intake = $cfg->param( "max_intake" );
my $start_yr = $cfg->param( "start_yr" );
my $start_month = $cfg->param( "start_month" );
my $start_day = $cfg->param( "start_day" );
my @clrs=('lgreen', 'yellow', 'green', 'green', 'dyellow', 'dgreen', 'black', 'black', 'dblue' );

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
my @prot = ();
my @carb = ();
my @fat = ();
my @weights = ();

my $y_min_value = 9999;
my $y_max_value = 0;

#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile","","");

my $sql_statement = "SELECT date, SUM(protein * amount / 100), SUM(carb * amount / 100), SUM(fat * amount / 100) FROM ${prefix}foods WHERE date >= ? AND date <= ? GROUP BY date ORDER BY date DESC";
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
        unshift( @prot, undef );
        unshift( @carb, undef );
        unshift( @fat, undef );
    }
    
    $first_dt ||= string_to_dt( $ary[0] );
    unshift( @dates , substr( $ary[0], 8 ) );
    unshift( @prot , $ary[1] );
    unshift( @carb , $ary[2] );
    unshift( @fat , $ary[3] );
    $y_min_value = $y_min_value < $ary[1] ? $y_min_value : $ary[1];
    $y_max_value = $y_max_value > $ary[1] ? $y_max_value : $ary[1];
    $last_dt = $curr_dt;
}  

while ( $prev_dt < $last_dt ) {
   unshift( @dates, substr( $last_dt->ymd('/'), 8 ) );
   unshift( @prot, undef );
   unshift( @carb, undef );
   unshift( @fat, undef );
   $last_dt->subtract( days => 1 );
}

while ( $first_dt < $stop_dt ) {
   $first_dt->add( days => 1 );
   push  @dates, substr( $first_dt->ymd('/'), 8 );
}

for my $index ( 0..$#dates ) {
    next unless $prot[$index] and $carb[$index] and $fat[$index];
    $prot[$index] *= 4;
    $carb[$index] *= 4;
    $fat[$index] *= 9;
    my $sum_all = $prot[$index] + $carb[$index] + $fat[$index];
    $prot[$index] = ( 100*$prot[$index] ) / $sum_all ;
    $carb[$index] = ( 100*$carb[$index] ) / $sum_all ;
    $fat[$index] = ( 100*$fat[$index] ) / $sum_all ;
}

my $avg_size = 14;
my $weight_exponent = 0.86;

my @w_avg_prot = get_balanced_ema( $avg_size, $weight_exponent, @prot );
my @w_avg_carb = get_balanced_ema( $avg_size, $weight_exponent, @carb );
my @w_avg_fat = get_balanced_ema( $avg_size, $weight_exponent, @fat );

splice( @dates, 0, 30 );
splice( @prot, 0, 30 );
splice( @carb, 0, 30 );
splice( @fat, 0, 30 );
splice( @w_avg_prot, 0, 30 );
splice( @w_avg_carb, 0, 30 );
splice( @w_avg_fat, 0, 30 );
splice( @weights, 0, 30 );
my @upper_limit;

for my $index ( 0..$#dates ) {
    next unless $prot[$index] and $carb[$index] and $fat[$index];
    
    $prot[$index] = $carb[$index] + $fat[$index] + ( $prot[$index] / 2 ) ;
    $carb[$index] = $fat[$index] + ( $carb[$index] / 2 ) ;
    $fat[$index] = ( $fat[$index] / 2 ) ;
}

for my $index ( 0..$#dates ) {
    $w_avg_prot[$index] = 1 if $w_avg_prot[$index] <= 0;
    $w_avg_carb[$index] = 1 if $w_avg_carb[$index] <= 0;
    $w_avg_fat[$index] = 1 if $w_avg_fat[$index] <= 0;
    my $sum_avg_all = $w_avg_prot[$index] + $w_avg_carb[$index] + $w_avg_fat[$index];
    $w_avg_prot[$index] = ( 100*$w_avg_prot[$index] ) / $sum_avg_all ;
    $w_avg_carb[$index] = ( 100*$w_avg_carb[$index] ) / $sum_avg_all ;
    $w_avg_fat[$index] = ( 100*$w_avg_fat[$index] ) / $sum_avg_all ;
    
    $w_avg_prot[$index] = $w_avg_carb[$index] + $w_avg_fat[$index] + $w_avg_prot[$index] ;
    $w_avg_carb[$index] = $w_avg_fat[$index] + $w_avg_carb[$index] ;
    $w_avg_fat[$index] = $w_avg_fat[$index] ;
}



my @target3;
$target3[0] = 20;
$target3[$#dates] = 20;

my @target1;
$target1[0] = 40;
$target1[$#dates] = 40;

my @target2;
$target2[0] = 60;
$target2[$#dates] = 60;


my $graph = GD::Graph::mixed->new( 400, 200 );
my @legend_keys = ( 'Protein', 'Carbs', 'Fat' );
$graph->set_legend( @legend_keys );
$graph->set(
#   x_label => 'Date',
   y_label => 'Percentage',
   y_min_value => 0,
   accent_treshold => 100,
   y_max_value => 100,
   title => "Nutritient Ratios (". $start_dt->ymd('/') ." - ". $stop_dt->ymd('/') .")",
   values_vertical => 1,
   x_label_skip => 7,
   x_long_ticks => 1,
   y_long_ticks => 1,
   x_tick_offset => 7-$start_dt->{local_c}->{day_of_week}+1,
   dclrs => [ @clrs ],
   types => [qw( area area area points points points lines lines )],
   markers => [6],
   marker_size => 2,
   line_width => 2,
   boxclr => "lgray",
   
   borderclrs => [ undef ],
) or warn( $graph->error );

print $query->header( -type => "image/png" );
my @data = ( \@dates, \@w_avg_prot, \@w_avg_carb, \@w_avg_fat, \@prot, \@carb, \@fat, \@target2, \@target3 );
my $image = $graph->plot( \@data ) or die( $graph->error );
print $image->png();


##############################################################################
1;
__END__

=pod

=head1 NAME

Diet Tracker - view_intake_graph.pl

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

