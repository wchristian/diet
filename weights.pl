#!/usr/bin/perl

use lib ('./lib');

use CGI::Carp qw(fatalsToBrowser);
use strict;
use CGI;
use DBI;
use Config::Simple;
use HTML::Template;
use DateTime;
use POSIX qw(ceil);

my $ini = "config.pl";
die "Can't open initialization file '$ini', $!\n" unless ( -f "$ini" );

my $cfg         = new Config::Simple($ini);
my $prefix      = $cfg->param("dbprefix");
my $weight_in   = $cfg->param("weight_in");
my $start_yr    = $cfg->param("start_yr");
my $start_month = $cfg->param("start_month");
my $start_day   = $cfg->param("start_day");

my $query = new CGI;

my $action     = $query->param('action');
my $id         = $query->param('id');
my $dt      = string_to_dt( $query->param( 'date' ) );
my $weight     = $query->param('weight');
my $start_dt = ( string_to_dt( $query->param( 'start_date' ) ) or string_to_dt( sprintf( "%04d/%02d/%02d", $start_yr, $start_month, $start_day ) ) );
my $stop_dt  = ( string_to_dt( $query->param( 'stop_date'  ) ) or DateTime->now->set( hour   => 0, minute => 0, second => 0,) );

my $valid         = '0';
my @error_strings = ();

my $dbh = DBI->connect( "dbi:SQLite:dbname=dbfile", "", "" );
my $sql_statement;
my $sth;

my $template = HTML::Template->new( filename => 'tmpl/weights.tmpl' );

if ( $action eq "add" ) {

    if ( !$dt ) {
        my %row = ( error => "The Date is improperly formatted." );
        push( @error_strings, \%row );
    }
    else {
        $sql_statement = "SELECT date FROM ${prefix}weights WHERE date = ?";
        $sth           = $dbh->prepare($sql_statement) or die "Could not prepare: " . $dbh->errstr();
        $sth->execute( $dt->ymd('/') ) or die "Error: " . $dbh->errstr();
        if ( $sth->fetchrow_array() ) {
            my %row = ( error => "An entry for this date already exists, only one weight entry allowed per day." );
            push( @error_strings, \%row );
        }
    }
    if ( $weight !~ /^[0-9]{1,3}(\.[0-9]{1,2})?$/ or $weight <= '0' ) {
        my %row = ( error => "The weight value cannot be empty or negative.  It cannot contain more than three digits before the decimal point or more than two digits after." );
        push( @error_strings, \%row );
    }

    my $error_size = @error_strings;

    if ( $error_size == 0 ) {
        $sql_statement = "INSERT INTO ${prefix}weights ( date, weight ) VALUES ( ?, ? )";
        $sth = $dbh->prepare($sql_statement) or die "Could not prepare: " . $dbh->errstr();
        $sth->execute( $dt->ymd('/'), $weight ) or die "Error: " . $dbh->errstr();
        
        $valid = '1';
        
        $template->param( date => $dt->ymd('/') );
    }

    $template->param( entry_amount => $weight );
    $template->param( entry_unit   => $weight_in );
    $template->param( add          => '1' );

}
elsif ( $action eq "edit" ) {
    my $sth;
    
    my $query_value = $query->param('value');
    print "Content-Type: text/html;charset=iso-8859-1\n\n";
    my $error_str = 'Error ';

    if ( $query_value !~ /^[0-9]{1,3}(\.[0-9]{1,2})?$/ or $query_value <= 0 ) {
        $error_str .= 'The weight value must be an integer greater than zero and containing no more than three digits before the decimal point or more than two digits after.';
    }

    my $error_size = @error_strings;

    if ( $error_str eq 'Error ' ) {
        my $sql_statement = "SELECT date FROM ${prefix}weights WHERE id = ?";
        $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
        $sth->execute( $id ) or die "Could not execute: " . $dbh->errstr();
        
        if ( my @ary = $sth->fetchrow_array() ) {
            $dt = string_to_dt( $ary[0] );
        }
        
        my $prev_dt = $dt->clone->subtract( days => 1 );
        $sql_statement = "SELECT date, weight FROM ${prefix}weights WHERE date = ?";
        $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
        $sth->execute( $prev_dt->ymd('/') ) or die "Could not execute: " . $dbh->errstr();
        
        if ( my @ary = $sth->fetchrow_array() ) {
            $sql_statement = "UPDATE ${prefix}weights SET weight = ? WHERE id = ?";
            $sth           = $dbh->prepare($sql_statement) or die "Could not prepare: " . $dbh->errstr();
            $sth->execute( $query_value, $id ) or die "Could not execute: " . $dbh->errstr();
        }
        else {
            $sql_statement = "UPDATE ${prefix}weights SET weight = ? WHERE id = ?";
            $sth           = $dbh->prepare($sql_statement) or die "Could not prepare: " . $dbh->errstr();
            $sth->execute( $query_value, $id ) or die "Could not execute: " . $dbh->errstr();
        }
        
        print "$query_value";
    }
    else {
        print "$error_str";
    }
    $sth->finish();
    $dbh->disconnect();
    exit;
}
elsif ( $action eq "delete" ) {
    my $dt;
    my ( $date, $weight );
    
    # Check if the id number exists/is in the valid range
    if ( $id eq "" or $id <= 0 ) {
        my %row =
          ( error => "The id number must be provided and greater than zero." );
        push( @error_strings, \%row );
    }

    my $error_size = @error_strings;

    if ( $error_size == 0 ) {

        # Query for the input id number
        $sql_statement =
          "SELECT date,weight FROM ${prefix}weights WHERE id = ?";
        $sth = $dbh->prepare($sql_statement)
          or die "Could not prepare: " . $dbh->errstr();
        $sth->execute($id) or die "Could not execute: " . $dbh->errstr();

        # If the id number was not found
        if ( my @ary = $sth->fetchrow_array() ) {
            $dt = string_to_dt( $ary[0] );
            $weight = $ary[1];
            $date = $ary[0];
        }
        else {
            my %row =
              ( error => "This entry does not exist and cannot be deleted." );
            push( @error_strings, \%row );
        }
    }

    $error_size = @error_strings;

    if ( $error_size == 0 ) {
        $template->param( weight      => $weight );
        $template->param( date        => date_convert($date) );
        $template->param( weight_unit => $weight_in );

        $sql_statement = "DELETE FROM ${prefix}weights WHERE id = ?";
        $sth           = $dbh->prepare($sql_statement)
          or die "Could not prepare: " . $dbh->errstr();
        $sth->execute($id) or die "Could not execute: " . $dbh->errstr();
        
        $valid = '1';
    }
    $template->param( delete => '1' );
}
else {
    $valid = '1';
}

$sql_statement = "SELECT date, weight,id FROM ${prefix}weights WHERE date >= ? AND date <= ? ORDER BY date DESC";
$sth = $dbh->prepare($sql_statement) or die "Could not prepare: " . $dbh->errstr();
$sth->execute( $start_dt->ymd('/'), $stop_dt->ymd('/') ) or die "Could not execute: " . $dbh->errstr();

my @weight_loop;
while ( my @ary1 = $sth->fetchrow_array() ) {
    my %row = (
        date1   => substr( $ary1[0], 5 ),
        weight1 => $ary1[1],
        id      => $ary1[2],
    );
    push( @weight_loop, \%row );
}

my $entries = (scalar @weight_loop);
$entries = ceil( $entries / 2 );

for my $index ( $entries .. ($entries*2) ) {
    last if !defined $weight_loop[$index];
    
    my $row1 = $weight_loop[$index-$entries];
    my $row2 = $weight_loop[$index];
    
    $row1->{date2} = $row2->{date1};
    $row1->{weight2} = $row2->{weight1};
    $row1->{id2} = $row2->{id};
}

splice( @weight_loop, $entries );

$template->param( start_date  => $start_dt->ymd('/') );
$template->param( stop_date   => $stop_dt->ymd('/') );
$template->param( weight_loop => \@weight_loop );

$template->param( start_year   => $start_dt->year );
$template->param( current_year => DateTime->now->year );
$template->param( current_date => DateTime->now->ymd('/') );

$template->param( valid         => $valid );
$template->param( error_strings => \@error_strings );

print "Content-Type: text/html;charset=iso-8859-1\n\n";
print $template->output;

sub date_convert {
    my $date_string = shift;
    my ( $year, $month, $day ) =
      ( $date_string =~ /^\s*(\d+).(\d+).(\d+)\s*$/x );
    $date_string = sprintf( "%04d/%02d/%02d", $year, $month, $day );
    return $date_string;
}

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

##############################################################################
1;
__END__

=pod

=head1 NAME

Diet Tracker - weights.pl


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

