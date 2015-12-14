#======================================================================
# Authen::CAS::Client::Response::Success
#
package Authen::CAS::Client::Response::Success;

use base qw/ Authen::CAS::Client::Response /;

sub new { my $class = shift; $class->SUPER::new( @_, _ok => 1 ) }

1
