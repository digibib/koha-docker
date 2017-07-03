package NCIPServer;

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

use Sys::Syslog qw(syslog);
use Modern::Perl;
use NCIP::Configuration;
use IO::Socket::INET;
use Socket qw(:DEFAULT :crlf);
use base qw(Net::Server::PreFork);

=head1 NAME
  
    NCIPServer

=head1 SYNOPSIS

    use NCIPServer;
    my $server = NCIPServer->new({config_dir => $config_dir});

=head1 FUNCTIONS

=head2 run()

  Apart from new, this is the only method you should ever call from outside this module
=cut

our $VERSION = '0.01';

# This sets up the configuration

my %transports = ( RAW => \&raw_transport, );

sub configure_hook {
    my ($self)        = @_;
    my $server        = $self->{'server'};
    my $config        = NCIP::Configuration->new( $server->{'config_dir'} );
    my $server_params = $config->('NCIP.server-params');
    while ( my ( $key, $val ) = each %$server_params ) {
        $server->{$key} = $val;
    }
    my $listeners = $config->('NCIP.listeners');
    foreach my $svc ( keys %$listeners ) {
        $server->{'port'} = $listeners->{$svc}->{'port'};
    }
    $self->{'local_config'} = $config;
}

# Debug, remove before release

sub post_configure_hook {
    my $self = shift;
    use Data::Dumper;
    print Dumper $self;
}

# this handles the actual requests
sub process_request {
    my $self     = shift;
    my $sockname = getsockname(STDIN);
    my ( $port, $sockaddr ) = sockaddr_in($sockname);
    $sockaddr = inet_ntoa($sockaddr);
    my $proto = $self->{server}->{client}->NS_proto();
    $self->{'service'} =
      $self->{'local_config'}->find_service( $sockaddr, $port, $proto );
    if ( !defined( $self->{service} ) ) {
        syslog( "LOG_ERR",
            "process_request: Unknown recognized server connection: %s:%s/%s",
            $sockaddr, $port, $proto );
        die "process_request: Bad server connection";
    }
    my $transport = $transports{ $self->{service}->{transport} };
    if ( !defined($transport) ) {
        syslog(
            "LOG_WARNING",
            "Unknown transport '%s', dropping",
            $self->{'service'}->{transport}
        );
        return;
    }
    else {
        &$transport($self);
    }
}

sub raw_transport {
    my $self = shift;
    my ($input);
    my $service = $self->{service};

    # place holder code, just echo at the moment
    while (1) {
        local $SIG{ALRM} = sub { die "raw_transport Timed Out!\n"; };
        $input = <STDIN>;
        if ($input) {
            print "You said $input";
        }
    }

}

1;
__END__
