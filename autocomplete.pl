#!/usr/bin/perl

BEGIN{
use Time::HiRes 'time';
open FH, '>', "time";
print FH time."\n";
}

use lib ('./lib');

use strict;
use CGI;
use DBI;
use JSON;
use Config::Simple;
use Encode 'from_to';

#open STDERR, '>>error.txt';
#open STDOUT, '>>log.txt';

my $query = new CGI;

my $type = $query->param( 'type' ) || 'prot';
my $item = $query->param( 'item' ) || 'Rice Waffles';
my $kcal = $query->param( 'kcal' );
my $prot = $query->param( 'prot' );
my $carb = $query->param( 'carb' );
my $fat  = $query->param( 'fat' );
my $amount  = $query->param( 'amount' );

# Unescapes characters and converts them from UTF-8 to iso-8859-1
$item =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
from_to( $item, 'UTF-8', 'iso-8859-1' );

my $ini = "config.pl";
( -f "$ini" ) || die "Can't open initialization file '$ini', $!\n";

my $cfg = new Config::Simple( $ini );
my $username = $cfg->param( "mysqluser" );
my $password = $cfg->param( "mysqlpasswd" );
my $database = $cfg->param( "database" );
my $host = $cfg->param( "dbserver" );
my $prefix = $cfg->param( "dbprefix" );

#my $dsn = "DBI:mysql:database=$database;host=$host";
#my $dbh = DBI->connect( $dsn, $username, $password );
my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile","","");

my $sql_statement = '';
my $sth;

my @values;
if ( $type eq "item" and $item ) {
	$sql_statement = "SELECT item FROM ${prefix}foods WHERE item LIKE ? GROUP BY item ORDER BY COUNT( item ) DESC";
	$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
	$sth->execute( '%' . $item . '%' ) or die "Could not execute: " . $dbh->errstr();
	
	while( my @ary = $sth->fetchrow_array() ) {
		my %row = (
			id => '',
			value => $ary[0],
			info => '',
		);
		push( @values, \%row );
	}
}
elsif ( $type eq "kcal" and $item ) {
	$sql_statement = "SELECT kcal FROM ${prefix}foods WHERE item = ? AND kcal LIKE ? GROUP BY kcal ORDER BY COUNT( kcal ) DESC";
	$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
	$sth->execute( $item, '%' . $kcal . '%' ) or die "Could not execute: " . $dbh->errstr();
	
	while( my @ary = $sth->fetchrow_array() ) {
		my %row = (
			id => '',
			value => $ary[0],
			info => '',
		);
		push( @values, \%row );
	}
}
elsif ( $type eq "prot" and $item ) {
	$sql_statement = "SELECT protein FROM ${prefix}foods WHERE item = ? AND protein LIKE ? GROUP BY protein ORDER BY COUNT( protein ) DESC";
	$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
	$sth->execute( $item, '%' . $prot . '%' ) or die "Could not execute: " . $dbh->errstr();
	
	while( my @ary = $sth->fetchrow_array() ) {
		my %row = (
			id => '',
			value => $ary[0],
			info => '',
		);
		push( @values, \%row );
	}
}
elsif ( $type eq "carb" and $item ) {
	$sql_statement = "SELECT carb FROM ${prefix}foods WHERE item = ? AND carb LIKE ? GROUP BY carb ORDER BY COUNT( carb ) DESC";
	$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
	$sth->execute( $item, '%' . $carb . '%' ) or die "Could not execute: " . $dbh->errstr();
	
	while( my @ary = $sth->fetchrow_array() ) {
		my %row = (
			id => '',
			value => $ary[0],
			info => '',
		);
		push( @values, \%row );
	}
}
elsif ( $type eq "fat" and $item ) {
	$sql_statement = "SELECT fat FROM ${prefix}foods WHERE item = ? AND fat LIKE ? GROUP BY fat ORDER BY COUNT( fat ) DESC";
	$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
	$sth->execute( $item, '%' . $fat . '%' ) or die "Could not execute: " . $dbh->errstr();
	
	while( my @ary = $sth->fetchrow_array() ) {
		my %row = (
			id => '',
			value => $ary[0],
			info => '',
		);
		push( @values, \%row );
	}
}
elsif ( $type eq "amount" and $item ) {
	$sql_statement = "SELECT amount FROM ${prefix}foods WHERE item = ? AND amount LIKE ? GROUP BY amount ORDER BY COUNT( amount ) DESC";
	$sth = $dbh->prepare( $sql_statement ) or die "Could not prepare: " . $dbh->errstr();
	$sth->execute( $item, '%' . $amount . '%' ) or die "Could not execute: " . $dbh->errstr();
	
	while( my @ary = $sth->fetchrow_array() ) {
		my %row = (
			id => '',
			value => $ary[0],
			info => '',
		);
		push( @values, \%row );
	}
}

my $results = {
	results => \@values,
};

print "Content-type: text/x-json;charset=iso-8859-1\n\n";
print to_json( $results );

print FH time."\n";

##############################################################################
exit;
__END__

=pod

=head1 NAME

Diet Tracker - autocomplete.pl


=head1 AUTHORS

Srijith K. Nair E<lt>srijith[at]srijith.netE<gt> &
Kyle Farnung E<lt>kyle[at]kylefarnung.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2007  Srijith K. Nair, Kyle Farnung

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

