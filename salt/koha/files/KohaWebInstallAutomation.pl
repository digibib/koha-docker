#!/usr/bin/perl

use strict;
use warnings;
use WWW::Mechanize;
use HTTP::Cookies;
use HTTP::Status qw(:constants :is status_message);
use Carp qw( confess );
   $SIG{__DIE__} =  \&confess;
   $SIG{__WARN__} = \&confess;

package KohaWebInstallAutomation;

sub new {
  my ($class, @args) = @_;
  my $self = {};
  bless $self, $class;
  $self->init(@args);

  return $self;
}

sub init {
  my ($self, @args) = @_;
  
  %{$self} = (
      uri  => 'http://localhost:8081',
      path => '',
      user => 'admin',
      pass => 'secret',
      previousStep => 0,
      mech => '',
      @args,
  );
  $self->test_response_code();

}

sub test_response_code {
  # Test for webinstaller by HEAD request
  my $self = shift;
  my $mech = WWW::Mechanize->new();
  $mech->agent('User-Agent=Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.5');
  $mech->cookie_jar(HTTP::Cookies->new);

  # follows redirect by default
  my $head = $mech->head($self->{uri}); 
  # Test header for redirect to webinstaller
  if ($head->is_success) {
    if ($head->previous && $head->previous->code() == HTTP::Status::HTTP_FOUND) { 
    # Redirect to webinstaller
      $self->{path} = $head->previous->headers->{location};
      $self->{mech} = $mech;
      clickthrough_installer($self);
    } else {
      if ( $self->{uri} == $head->previous->headers->{location} ) {
        print "{\"comment\":\"Instance is already installed\"}";
      } else {
        die "HTTPSuccess, but it is unclear how we got to " . $head->previous->headers->{location};
      }
    }
  } else {
    die "{\"comment\":\"Request failed. URI: $head->previous->headers->{location}\"}";
  }

}

sub clickthrough_installer {
  my $self = shift;
  step_one($self);
  step_two($self);
  step_three($self);
}

sub do_login {
  my $self = shift;
  my $installer = $self->{mech}->get($self->{uri});
  my $login = $self->{mech}->submit_form( with_fields => {
        userid   => $self->{user},
        password => $self->{pass},
    });
}

sub step_one {
  my $self = shift;
  do_login($self);
  $self->{mech}->submit_form( form_name => "language" );
  $self->{mech}->submit_form( form_name => "checkmodules" );
  $self->{path} = '/cgi-bin/koha/installer/install.pl?step=2';
}

sub step_two {
  my $self = shift;
  $self->{mech}->submit_form( form_name => "checkinformation" );
  $self->{mech}->submit_form( form_name => "checkdbparameters" );
  $self->{mech}->submit_form();
  $self->{mech}->submit_form();
  $self->{mech}->follow_link( url => "install.pl?step=3&op=choosemarc" );
  $self->{mech}->set_fields( marcflavour => "MARC21");
  $self->{mech}->submit_form( form_name => "frameworkselection");
  $self->{mech}->submit_form( form_name => "frameworkselection"); # yes, it occurs twice
}

sub step_three {
  my $self = shift;
  $self->{mech}->submit_form();
  print "{\"comment\":\"Successfully completed the install process\"}";
}
