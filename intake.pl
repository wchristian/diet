#!/usr/bin/perl

use lib ('./lib');

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use DBI;
use Config::Simple;
use HTML::Entities;
use HTML::Template;
use Time::localtime;

# Get the CGI query data
my $query=new CGI;
my $action = $query->param( 'action' );
my $query_form_submit = $query->param( 'form_submit' );
my $query_id = $query->param( 'id' );
my $query_item = $query->param( 'item' );
my $query_amount = $query->param( 'amount' );
my $query_kcal = $query->param( 'kcal' );
my $query_prot = $query->param( 'prot' );
my $query_carb = $query->param( 'carb' );
my $query_fat  = $query->param( 'fat' );
my $query_date = $query->param( 'date' );
my $start_date = $query->param( 'start_date' );
my $stop_date  = $query->param( 'stop_date' );
my $page = $query->param( 'page' ) ? $query->param( 'page' ) : 1;

# Get the config file data
my $ini = "config.pl";
( -f "$ini" ) or die "Can't open initialization file '$ini', $!\n";

my $cfg = new Config::Simple($ini);
my $username = $cfg->param( "mysqluser" );
my $password = $cfg->param( "mysqlpasswd" );
my $database = $cfg->param( "database" );
my $host = $cfg->param( "dbserver" );
my $prefix = $cfg->param( "dbprefix" );
my $en_autosuggest = $cfg->param( "en_autosuggest" );
my $days_per_page = $cfg->param( "days_per_page" );
my $start_yr = $cfg->param( "start_yr" );
my $start_month = $cfg->param( "start_month" );
my $start_day = $cfg->param( "start_day" );

# Get the current local time
my $tm = localtime;
my ( $DAY, $MONTH, $YEAR ) = ( $tm->mday, ( $tm->mon ) + 1, $tm->year + 1900 );
my $today = sprintf( "%04d/%02d/%02d", $YEAR, $MONTH, $DAY );

# Check the dates for proper formatting
if ( $start_date !~ m!^[0-9]{4,4}/[0-9]{1,2}/[0-9]{1,2}$! ) {
	$start_date = sprintf( "%04d/%02d/%02d", $start_yr, $start_month, $start_day );
}
if ( $stop_date !~ m!^[0-9]{4,4}/[0-9]{1,2}/[0-9]{1,2}$! ) {
	$stop_date = $today;
}

# Set up error variables
my $valid = '0';
my @error_strings = ();

# Set up database variables
#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile","","");
my $sql_statement;
my $sth;

# Create form variables
my $form_item;
my $form_amount;
my $form_kcal;
my $form_prot;
my $form_carb;
my $form_fat;
my $form_date = $today;
my $form_id;

# Set up the template
my $template = HTML::Template->new( filename => 'tmpl/intake.tmpl' );

#Check the action variable
if ( $action eq "add" ) {
   # Check for proper input of data
   if ( $query_item eq "" or length( $query_item ) > 50 ) {
      my %row = ( error => "The Item description must be less than 50 characters and cannot be left blank." );
      push( @error_strings, \%row );
   }
   if ( $query_date !~ m!^[0-9]{4,4}/[0-9]{1,2}/[0-9]{1,2}$! ) {
      my %row = ( error => "The Date is improperly formatted." );
      push( @error_strings, \%row );
   }

   # Check the size of the error strings
   my $error_size = @error_strings;

   if ( $error_size == 0 ) {
      $sql_statement = "INSERT INTO ${prefix}foods ( date, item, kcal, protein, carb, fat, amount ) VALUES ( ?, ?, ?, ?, ?, ?, ? )";
      $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
      $sth->execute( $query_date, $query_item, $query_kcal, $query_prot, $query_carb, $query_fat, $query_amount ) or die "Could not execute: " . $dbh->errstr();
      $valid = '1';
   } else {
      $form_item = $query_item;
      $form_amount = $query_amount;
      $form_kcal = $query_kcal;
      $form_prot = $query_prot;
      $form_carb = $query_carb;
      $form_fat = $query_fat;
   }
	
   $form_date = $query_date;

   encode_entities( $query_item );

   $template->param( add => '1' );
   $template->param( item_type => $query_item );
   $template->param( item_amount => $query_kcal );
   $template->param( date => $query_date );
}
elsif ( $action eq "edit") {
   my $query_id = $query->param('id');
   # $id is of form 'n:f' or 'n:c', f for food name and c for calorie
   my $item = substr($query_id, length($query_id) -1);
   chop $query_id;
   my $query_value = $query->param('value');
   print "Content-Type: text/html;charset=iso-8859-1\n\n";
   my $error_str='Error ';

   if ( ($item eq 'f') and ($query_value eq "" or length( $query_value ) > 50 )) {
      $error_str.='The Item description must be less than 50 characters and cannot be left blank.'
   }
   if ( ($item eq 'c') and ($query_value !~ /^[1-9][0-9]{0,3}$/ or $query_value <= 0 )) {
	   $error_str.='The KCal value must be an integer greater than zero and containing no more than four digits.';
   }

   my $error_size = @error_strings;

   if ( $error_str eq 'Error ' ) {
      if ($item eq 'f') {
         $sql_statement = "UPDATE ${prefix}foods SET item = ? WHERE id = ?";
      }
		elsif($item eq 'm') {
         $sql_statement = "UPDATE ${prefix}foods SET amount = ? WHERE id = ?";
      }
		elsif($item eq 'c') {
         $sql_statement = "UPDATE ${prefix}foods SET kcal = ? WHERE id = ?";
      }
		elsif($item eq 'p') {
         $sql_statement = "UPDATE ${prefix}foods SET protein = ? WHERE id = ?";
      }
		elsif($item eq 'a') {
         $sql_statement = "UPDATE ${prefix}foods SET carb = ? WHERE id = ?";
      }
		elsif($item eq 't') {
         $sql_statement = "UPDATE ${prefix}foods SET fat = ? WHERE id = ?";
      }
      $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
      $sth->execute( $query_value, $query_id ) or die "Could not execute: " . $dbh->errstr();
      print "$item:$query_value"; # response need to be in form f:new_value or c:new_value for AJAX to parse

   } else {
	   print "$error_str";
   }
   $sth->finish();
   $dbh->disconnect();
   exit;
}
elsif ( $action eq "delete" ) {
   # Check if the id number exists/is in the valid range
   if ( $query_id eq "" or $query_id <= 0 ) {
      my %row = ( error => "The id number must be provided and greater than zero." );
      push( @error_strings, \%row );
   }
	
   my $error_size = @error_strings;
	
   if ( $error_size == 0 ) {
      # Query for the input id number
      $sql_statement = "SELECT date, item, kcal FROM ${prefix}foods WHERE id = ?";
      $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
      $sth->execute( $query_id ) or die "Could not execute: ". $dbh->errstr();

      # If the id number was not found
      if ( !$sth->fetchrow_array() ) {
         my %row = ( error => "This entry does not exist and cannot be deleted." );
         push( @error_strings, \%row );
      }
   }
	
   $error_size = @error_strings;

   if ( $error_size == 0 ) {
      my ($date, $item, $kcal);
      $sth->bind_columns( undef, \$date, \$item, \$kcal );
      $sth->fetch();
      $template->param( item_type => $item );
      $template->param( item_amount => $kcal );
      $template->param( date => date_convert( $date ) );

      $sql_statement = "DELETE FROM ${prefix}foods WHERE id = ?";
      $sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
      $sth->execute( $query_id ) or die "Could not execute: " . $dbh->errstr();
      $valid = '1';
   }
	
   $template->param( delete => '1' );
} else {
   $valid = '1';
}

$sql_statement = "SELECT date, sum(kcal * amount / 100), sum(protein * amount / 100), sum(carb * amount / 100), sum(fat * amount / 100) FROM ${prefix}foods WHERE date >= ? AND date <= ? GROUP BY date ORDER BY date DESC LIMIT ?, ?";
$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
# We use $days_per_page+1 to check whether we have enough for a 'next page' without having to use
# GROUP BY or COUNT(DISTINCT)
$sth->execute( $start_date, $stop_date, ( $page - 1 ) * $days_per_page, ($days_per_page +1)) or die "Could not execute: " . $dbh->errstr();

my $details_sql = "SELECT item, kcal, id, protein, carb, fat, amount, (kcal * amount / 100), ( (protein*4 + carb*4 + fat*9) * amount / 100 ) FROM ${prefix}foods WHERE date = ?";
my $sth2 = $dbh->prepare( $details_sql ) or die "Could not prepare: " . $dbh->errstr();

my @outerloop;  # the outer loop data will be put in here
my $num_rows=0;
while(my @ary=$sth->fetchrow_array()) {
   $num_rows++;
   last if ($num_rows > $days_per_page); # we need a 'next' page
   my $query_date = $ary[0];
   my $sum = sprintf ( "%d", $ary[1]);
   my $sum_p = sprintf ( "%d", $ary[2]);
   my $sum_c = sprintf ( "%d", $ary[3]);
   my $sum_f = sprintf ( "%d", $ary[4]);
   my $default_collapse = dates_equal( $query_date, $today ) ? '0' : '1';

   $sth2->execute( $query_date ) or die "Could not execute: " . $dbh->errstr();
	
   my @innerloop;
   while(my @ary2 = $sth2->fetchrow_array()) {
      my %row = (
         item => encode_entities( $ary2[0] ),
         calorie => $ary2[1],
         cal_rough => $ary2[7],
         cal_macro => $ary2[8],
         protein => $ary2[3],
         carb => $ary2[4],
         fat => $ary2[5],
         id => $ary2[2],
         date => $query_date,
         amount => $ary2[6],	
      );
      push(@innerloop,\%row); 
   }
   my $id_date = $query_date;
   $id_date =~ s@/@_@g;
   my %outerrow = ( item_details_id => $id_date, date_sum => $query_date, sum => $sum, sum_p => $sum_p, sum_c => $sum_c, sum_f => $sum_f, inner_loop => \@innerloop );
   push( @outerloop, \%outerrow );
}

$sth->finish();
$dbh->disconnect();

$template->param( outer_loop => \@outerloop );
$template->param( start_date => $start_date );
$template->param( stop_date => $stop_date );

$template->param( form_item => $form_item );
$template->param( form_kcal => $form_kcal );
$template->param( form_amount => $form_amount );
$template->param( form_prot => $form_prot );
$template->param( form_carb => $form_carb );
$template->param( form_fat => $form_fat );
$template->param( form_date => $form_date );
$template->param( form_id => $form_id );

$template->param( start_year => $start_yr );
$template->param( current_year => $YEAR );
if ($num_rows > $days_per_page) {
   $template->param( next_page_num => $page + 1 );
}
$template->param( prev_page_num => $page - 1 );

$template->param( en_autosuggest => $en_autosuggest );
$template->param( valid => $valid );
$template->param( error_strings => \@error_strings );

print "Content-Type: text/html;charset=iso-8859-1\n\n";
print $template->output;

sub dates_equal {
   my $first = shift;
   my $second = shift;
	
   my ($year1, $month1, $day1) = ($first =~ /^\s*(\d+).(\d+).(\d+)\s*$/x);
   my ($year2, $month2, $day2) = ($second =~ /^\s*(\d+).(\d+).(\d+)\s*$/x);
	
   if ( $year1 == $year2 && $month1 == $month2 && $day1 == $day2 ) {
      return '1';
   } else {
      return '0';
	}
}

sub date_convert {
   my $date_string = shift;
	my ($year, $month, $day) = ($date_string =~ /^\s*(\d+).(\d+).(\d+)\s*$/x);
	$date_string = sprintf( "%04d/%02d/%02d", $year, $month, $day );
   return $date_string;
}

##############################################################################
1;
__END__

=pod

=head1 NAME

Diet Tracker - intake.pl


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

