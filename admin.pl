#!/usr/bin/perl

use lib ('./lib');

use strict;
use CGI;
use HTML::Template;

my $query = new CGI;
my $edit = $query->param('edit');
my $newconfig = $query->param('newconfig');

my $config="config.pl";
my $fileContent='';

my $valid=0;
my $template = HTML::Template->new( filename => 'tmpl/admin.tmpl' );

if (!$edit) {
   $valid=1;
   # Set up the template
   loadconfig();
   $template->param( config_content => $fileContent );
}
elsif($edit==1) {
   open(NEW, ">", $config) or die "can't open $config: $!";
   print NEW $newconfig;
   close NEW;
   $valid=1;
   $template->param( edit => 1);
   loadconfig();
   $template->param( config_content => $fileContent );
}

$template->param( valid => $valid );
print "Content-Type: text/html;charset=iso-8859-1\n\n";
print $template->output;

sub loadconfig {
   open(FILE, "< $config") or die "Couldn't open $config for reading: $!\n";
   while (<FILE>) {
      $fileContent = $fileContent . $_;
   }
   close FILE;
}
##############################################################################
1;
__END__

=pod

=head1 NAME

Diet Tracker - admin.pl


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
 
