#======================================================================
# Authen::CAS::Client::Response::Failure
#
package Authen::CAS::Client::Response::Failure;

use base qw/ Authen::CAS::Client::Response /;

sub _ATTRIBUTES () { code => undef, message => '', $_[0]->SUPER::_ATTRIBUTES }

sub new { my $class = shift; $class->SUPER::new( @_, _ok => 0 ) }

sub code    { my ( $self ) = @_; $self->{code} }
sub message { my ( $self ) = @_; $self->{message} }

1