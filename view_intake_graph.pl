#!/usr/bin/perl

use 5.010;
use lib '.';

use CGI::Carp qw(fatalsToBrowser);
use strict;
use CGI;
use DBI;
use GD::Graph::mixed;
use Time::localtime;
use Config::Simple;
use EMA 'get_balanced_ema';
use DateTime;
use List::Util qw( max min );

my $pre_range = 300;

my $query = CGI->new;

my $stop_dt = ( string_to_dt( $query->param( 'stop_date' ) ) or DateTime->now );
$stop_dt->set( hour => 0, minute => 0, second => 0, );
my $start_dt = ( string_to_dt( $query->param( 'start_date' ) ) or $stop_dt->clone->subtract( days => 30 ) );
my $prev_dt = $start_dt->clone->subtract( days => $pre_range );

my $ini = "config.pl";
die "Can't open initialization file '$ini', $!\n" if !-f "$ini";

my $cfg            = Config::Simple->new( $ini );
my $username       = $cfg->param( "mysqluser" );
my $password       = $cfg->param( "mysqlpasswd" );
my $database       = $cfg->param( "database" );
my $host           = $cfg->param( "dbserver" );
my $prefix         = $cfg->param( "dbprefix" );
my $moving_avg_pts = $cfg->param( "moving_avg_pts" );
my $max_intake     = $cfg->param( "max_intake" );
my $start_yr       = $cfg->param( "start_yr" );
my $start_month    = $cfg->param( "start_month" );
my $start_day      = $cfg->param( "start_day" );

sub string_to_dt {
    my ( $string ) = @_;

    my $dt;
    if ( $string =~ m!^([0-9]{4,4})/([0-9]{1,2})/([0-9]{1,2})$! ) {
        $dt = DateTime->new(
            year  => $1,
            month => $2,
            day   => $3,
        );
    }

    return $dt;
}

my @dates   = ();
my @kcals   = ();

my $y_min_value   = 9999;
my $y_max_value   = 0;
my $y_tick_number = 16;

#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect( "dbi:SQLite:dbname=dbfile", "", "" );

my $sql_statement =
"SELECT date, SUM( kcal * amount / 100 ) FROM ${prefix}foods WHERE date >= ? AND date <= ? GROUP BY date ORDER BY date DESC";
my $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( $prev_dt->ymd( '/' ), $stop_dt->ymd( '/' ) ) or die "Could not execute: " . $dbh->errstr();

my $last_dt = $stop_dt->clone;
my $first_dt;
my $count = 0;
$last_dt->add( days => 1 );
while ( my @ary = $sth->fetchrow_array() ) {
    my $curr_dt = string_to_dt( $ary[0] );

    my $delta = $curr_dt->delta_days( $last_dt )->delta_days - 1;
    for ( ( '' ) x $delta ) {
        $last_dt->subtract( days => 1 );
        $first_dt ||= string_to_dt( $last_dt->ymd( '/' ) );
        unshift( @dates, substr( $last_dt->ymd( '/' ), 8 ) );
        unshift( @kcals, undef );
        $count++;
    }

    $first_dt ||= string_to_dt( $ary[0] );
    unshift( @dates, substr( $ary[0], 8 ) );
    unshift( @kcals, $ary[1] );
    $y_min_value = $y_min_value < $ary[1] ? $y_min_value : $ary[1];
    $y_max_value = $y_max_value > $ary[1] ? $y_max_value : $ary[1];
    $last_dt     = $curr_dt;
}

while ( $prev_dt < $last_dt ) {
    unshift( @dates, substr( $last_dt->ymd( '/' ), 8 ) );
    unshift( @kcals, undef );
    $last_dt->subtract( days => 1 );
}

while ( $first_dt < $stop_dt ) {
    $first_dt->add( days => 1 );
    push @dates, substr( $first_dt->ymd( '/' ), 8 );
}

my $graph_spread = $y_max_value - $y_min_value;

$y_min_value -= $graph_spread * 0.05;
$y_max_value += $graph_spread * 0.05;

$y_min_value = sprintf( "%d", $y_min_value );
$y_max_value = sprintf( "%d", $y_max_value );

$y_max_value = 3500;    # if $y_max_value > 3000;

$y_min_value = 1500;

my $y_scale_step = ( $y_max_value - $y_min_value ) / $y_tick_number;

while ( $y_scale_step =~ /\./ ) {
    $y_max_value++;
    $y_scale_step = ( $y_max_value - $y_min_value ) / $y_tick_number;
}

$sql_statement = "SELECT date, weight  FROM ${prefix}weights WHERE date >= ? AND date <= ? ORDER BY date DESC";
$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( $prev_dt->ymd( '/' ), $stop_dt->ymd( '/' ) ) or die "Could not execute: " . $dbh->errstr();

$last_dt = $stop_dt->clone;
$last_dt->add( days => 1 );

my @weights;
while ( my @ary = $sth->fetchrow_array ) {
    my $curr_dt = string_to_dt( $ary[0] );

    my $delta = $curr_dt->delta_days( $last_dt )->delta_days - 1;
    for ( ( '' ) x $delta ) {
        $last_dt->subtract( days => 1 );
        unshift( @weights, undef );
    }

    unshift( @weights, $ary[1] );
    $last_dt = $curr_dt;
}

my $delta = $prev_dt->delta_days( $last_dt )->delta_days;
unshift @weights, undef for ( '' ) x $delta;

my $avg_size        = 14;
my $weight_exponent = 0.86;

@weights = get_balanced_ema( $avg_size, $weight_exponent, @weights );
my @avg = @kcals;
$avg[-1] = undef;
@avg = get_balanced_ema( $avg_size, $weight_exponent, @avg );

my $kcal_per_kg = 6800;

my @loss_maint;
my $maint_diff = 1;
for my $i ( 0 .. $#weights ) {
    next if !defined $avg[$i];

    my $start = max( $i - $maint_diff, 0 );
    my $days  = max( $i - $start,      1 );

    my $weight_change = $weights[$i] - $weights[$start];
    $weight_change /= $days;
    my $deficit = $kcal_per_kg * $weight_change;

    $loss_maint[$i] = $avg[$i] - $deficit;
}

my @smooth_loss_maint = get_balanced_ema( $avg_size, $weight_exponent, @loss_maint );

#@smooth_loss_maint = get_balanced_ema( $avg_size, $weight_exponent, @smooth_loss_maint );
#@smooth_loss_maint = get_balanced_ema( $avg_size, $weight_exponent, @smooth_loss_maint );

my @weight_based_diet_cals;

for my $i ( 0 .. $#smooth_loss_maint ) {
    $weight_based_diet_cals[$i] = $smooth_loss_maint[$i] - ( $kcal_per_kg / 7 * 0.2 );
}

splice( @avg,        0, $pre_range );
splice( @dates,      0, $pre_range );
splice( @kcals,      0, $pre_range );
splice( @loss_maint, 0, $pre_range - 1 );
pop @loss_maint;
splice( @smooth_loss_maint, 0, $pre_range - 1 );
pop @smooth_loss_maint;
splice( @weight_based_diet_cals, 0, $pre_range - 1 );
pop @weight_based_diet_cals;

my @clrs = ( 'gray', 'dgreen', 'dyellow', 'lred', $cfg->param( "w_avg_clr" ) );

my $graph = GD::Graph::mixed->new( 410, 200 );
my @legend_keys = ( 'Daily', "Loss Level", "Curr. Maint.", "Trend ($moving_avg_pts)" );
$graph->set_legend( @legend_keys );
$graph->set(

    #   x_label => 'Date',
    y_label         => 'KCal',
    y_min_value     => $y_min_value,
    y_max_value     => $y_max_value,
    y_tick_number   => $y_tick_number,
    title           => "Calorie Intake (" . $start_dt->ymd( '/' ) . " - " . $stop_dt->ymd( '/' ) . ")",
    values_vertical => 1,
    x_label_skip    => 7,
    y_label_skip    => 4,
    x_long_ticks    => 1,
    y_long_ticks    => 1,
    x_tick_offset   => 7 - $start_dt->{local_c}->{day_of_week} + 1,
    dclrs           => [@clrs],
    types           => [qw(points lines)],
    markers         => [6],
    marker_size     => 2,
    line_width      => 2,
    boxclr          => "lgray",
    r_margin        => 5,
) or warn( $graph->error );

print $query->header( -type => "image/png" );
my @data = ( \@dates, \@kcals, \@weight_based_diet_cals, \@smooth_loss_maint, \@avg );
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
