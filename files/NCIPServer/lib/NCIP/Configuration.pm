package NCIP::Configuration;

# Copyright 2013 Catalyst IT <chrisc@catalyst.net.nz>

# This file is part of NCIPServer
#
# NCIPServer is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# NCIPServer is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with NCIPServer; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


=head1 NAME
  
  NCIP::Configuration

=head1 SYNOPSIS

  use NCIP::Configuration;
  my $config = NCIP::Configuration->new($config_dir);

=cut

use Modern::Perl;
use NCIP::Configuration::Service;
use base qw(Config::Merge);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my @services;

    # we might have a few services set them up safely
    if ( ref( $self->('NCIP.listeners.service') ) eq 'ARRAY' ) {
        @services = $self->('NCIP.listeners.service');
    }
    else {
        @services = ( $self->('NCIP.listeners')->{'service'} );
    }
    my %listeners;
    foreach my $service (@services) {
        my $serv_object = NCIP::Configuration::Service->new($service);
        $listeners{ lc $service->{'port'} } = $serv_object;
    }
    $self->{'listeners'} = \%listeners;
    return $self;
}

=head1 FUNCTIONS

=head2 find_service

  my $service = $config->($sockaddr, $port, $proto);

  Used to find which service you should be using to answer an incoming request

=cut

sub find_service {
    my ( $self, $sockaddr, $port, $proto ) = @_;
    my $portstr;
    foreach my $addr ( '', '*:', "$sockaddr:" ) {
        $portstr = sprintf( "%s%s/%s", $addr, $port, lc $proto );
        Sys::Syslog::syslog( "LOG_DEBUG",
            "Configuration::find_service: Trying $portstr" );
        last if ( exists( ( $self->{listeners} )->{$portstr} ) );
    }
    return $self->{listeners}->{$portstr};
}
1;

