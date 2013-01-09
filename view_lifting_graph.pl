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
use Math::Business::WMA;
use DateTime;
use POSIX qw(ceil floor);
use List::Util qw( max  min );
use EMA 'get_balanced_ema';

my $query = new CGI;
#'2008/11/27'
my $stop_dt  = ( string_to_dt( undef or $query->param( 'stop_date'  ) ) or DateTime->now->set( hour   => 0, minute => 0, second => 0,) );
my $start_dt = ( string_to_dt( undef or $query->param( 'start_date' ) ) or $stop_dt->clone->subtract( days => 30 ) );
my $days = $start_dt->delta_days( $stop_dt )->{days};
my $prev_dt  = $start_dt->clone->subtract( days => 300 );

my %lifts = (
    squat => "Squat",
    press => "Press",
    benchpress => "B-Press",
    deadlift => "D-Lift",
    powerclean => "P-Clean",
    dbrows => "DB Rows",
    dbpress => "DB Press",
);


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
my @clrs=($cfg->param( "daily_clr" ), $cfg->param( "w_avg_clr" ), undef, 'lblue', 'lyellow');

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
my @trend = ();

my %days;
my %arrays;

my $y_min_value = 999;
my $y_max_value = 0;

#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile","","");

my $sql_statement = "SELECT date, weight, type FROM ${prefix}lifting WHERE date >= ? AND date <= ? ORDER BY date DESC";
my $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( $prev_dt->ymd('/'), $stop_dt->ymd('/') ) or die "Could not execute: " . $dbh->errstr();

while( my $row = $sth->fetchrow_hashref() ) {
    my $date = $row->{date};
    $days{$date}{$row->{type}} = $row->{weight};
}

my $curr_dt = $prev_dt->clone;

while ( $curr_dt <= $stop_dt ) {
    my $date = $curr_dt->ymd('/');
    
    my $array_date = $date;
    $array_date  =~ s/^.{8}//;
    push @{ $arrays{dates} }, $array_date;
    
    for my $type ( keys %lifts ) {
        my $value = $days{$date}{$type};
        $y_min_value = min( $value, $y_min_value ) if defined $value;
        $y_max_value = max( $value, $y_max_value );
        push @{ $arrays{$type} }, $value || undef;
    }
   
   $curr_dt->add( days => 1 )
}

my $avg_size = 90;
my $weight_exponent = 0.97;


for my $type ( keys %lifts ) {
    my @avg = get_balanced_ema( $avg_size, $weight_exponent, @{ $arrays{$type} } );
    $arrays{$type.'_avg'} = \@avg;
}

$y_min_value = 30;
$y_max_value = 180;

my $snip_length = $#{$arrays{dates}};
$snip_length -= $days;
splice( @{ $arrays{$_} }, 0, $snip_length ) for keys %arrays;

my $last = $#{ $arrays{dates} };

$arrays{squat_limit} = [];
$arrays{deadlift_limit} = [];
$arrays{benchpress_limit} = [];
$arrays{press_limit} = [];
$arrays{powerclean_limit} = [];

my $graph = GD::Graph::mixed->new( 400, 220 );
my @legend_keys = (   $lifts{squat}, $lifts{deadlift}, $lifts{benchpress}, $lifts{press} ); #, $lifts{powerclean}, $lifts{dbrows}, $lifts{dbpress}  );
$graph->set_legend( @legend_keys );
$graph->set(
    x_label => "Date - $days days",
    y_label => "Weight in $weight_in",
#    y_tick_number => ($y_max_value - $y_min_value),
    y_min_value => $y_min_value,
    y_max_value => $y_max_value,
    title => "Est. Maxes (". $start_dt->ymd('/') ." - ". $stop_dt->ymd('/') .")",
#    values_vertical => 1,
    x_label_skip => 7,
    long_ticks => 1,
    x_tick_offset => 7-$start_dt->{local_c}->{day_of_week}+1,
    dclrs => [qw(
        lred lblue black lpurple
        lred lblue black lpurple
    )],
    types => [qw(
        lines  lines  lines  lines
        points points points points
    )],
    markers => [1],
    marker_size => 2,
    boxclr => "lgray",
    line_width => 1,
) or warn( $graph->error );

print $query->header( -type => "image/png" );
my @data = (
    $arrays{dates},
    $arrays{squat_avg}, $arrays{deadlift_avg}, $arrays{benchpress_avg}, $arrays{press_avg},
    $arrays{squat},     $arrays{deadlift},     $arrays{benchpress},     $arrays{press},
);
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

