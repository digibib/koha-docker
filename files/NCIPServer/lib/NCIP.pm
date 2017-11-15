package NCIP;
use NCIP::Configuration;
use NCIP::Response;
use NCIP::Problem;
use Modern::Perl;
use XML::LibXML;
use XML::LibXML::Simple qw/XMLin/;
use Try::Tiny;
use Module::Load;
use Template;
use Log::Log4perl;
use Encode qw( encode_utf8 decode_utf8 );
use Object::Tiny qw{config namespace ils};

our $VERSION           = '0.01';
our $strict_validation = 0;        # move to config file

=head1 NAME

    NCIP

=head1 SYNOPSIS

    use NCIP;
    my $nicp = NCIP->new($config_dir);

=head1 FUNCTIONS

=cut

sub new {
    my $proto      = shift;
    my $class      = ref $proto || $proto;
    my $config_dir = shift;
    my $self       = {};
    my $config     = NCIP::Configuration->new($config_dir);
    $self->{config}    = $config;
    $self->{namespace} = $config->('NCIP.namespace.value');
    Log::Log4perl->init($config_dir . "/log4perl.conf");
    # load the ILS dependent module
    my $module = $config->('NCIP.ils.value');
    load $module || die "Can not load ILS module $module";
    my $ils = $module->new( name => $config->('NCIP.ils.value') );
    $self->{'ils'} = $ils;
    return bless $self, $class;

}

=head2 process_request()

 my $output = $ncip->process_request($xml);

=cut

sub process_request {
    my $self = shift;
    my $xml  = shift;
    #my $xml            = encode_utf8( shift ); # We shouldn't encode if we get an already encoded UTF9 string

    # Declare our response object:
    my $response;
    my $type;

    # Make an object out of the XML request message:
    my $request = $self->handle_initiation($xml);
    if ($request) {
        # Get the request type from the message:
        $type = $self->{ils}->parse_request_type($request);
        if ($type) {
            my $message = lc($type);
            if ($self->{ils}->can($message)) {
                $response = $self->{ils}->$message($request);
            } else {
                $response = $self->{ils}->unsupportedservice($request);
            }
        }
    }

    # The ILS is responsible for handling internal errors, so we
    # assume that not having a response object at this point means we
    # got an invalid message sent to us, or it got garbled in
    # transmission.
    unless ($response) {
        my $problem = NCIP::Problem->new();
        $problem->ProblemType("Invalid Message Syntax Error");
        $problem->ProblemDetail("Unable to parse the NCIP message.");
        $problem->ProblemElement("NULL");
        $problem->ProblemValue("Unable to parse the NCIP message.");
        # Make a response and add our problem.
        $response = NCIP::Response->new();
        $response->problem($problem);
    }

    my $rendered_output = $self->render_output($response);
my $log = Log::Log4perl->get_logger("NCIP");
$log->info($xml);
$log->info($rendered_output);
    # Log the XML messages to the ILS
    $self->{ils}->log_to_ils( $type, $xml );
    $self->{ils}->log_to_ils( $type . 'Response', $rendered_output );

    return $rendered_output;
}

=head2 handle_initiation

=cut

sub handle_initiation {
    my $self = shift;
    my $xml  = shift;

    my $dom;
    my $log = Log::Log4perl->get_logger("NCIP");

    eval { $dom = XML::LibXML->load_xml( string => $xml ); };
    if ($@) {
        $log->info("Invalid xml we can not parse it ");
    }
    if ($dom) {

        # should check validity with validate at this point
        if ( $strict_validation && !$self->validate($dom) ) {

            # we want strict validation, bail out if dom doesnt validate
#            warn " Not valid xml";

            # throw/log error
            return;
        }
        return XMLin( $dom, NsStrip => 1, NormaliseSpace => 2 );
    }
    else {
        $log->info("We have no DOM");

        return;
    }
}

sub validate {

    # this should perhaps be in it's own module
    my $self = shift;
    my $dom  = shift;
    try {
        $dom->validate();
    }
    catch {
        warn "Bad xml, caught error: $_";
        return;
    };

    # we could validate against the schema here, might be good?
    # my $schema = XML::LibXML::Schema->new(string => $schema_str);
    # eval { $schema->validate($dom); }
    # perhaps we could check the ncip version and validate that too
    return 1;
}

=head2 render_output

  my $output = $self->render_output($response);

Accepts a NCIP::Response object and renders the response.tt template
based on its input.  The template output is returned.

=cut

sub render_output {
    my $self         = shift;
    my $response = shift;

    my $template = Template->new(
        {
            INCLUDE_PATH => $self->config->('NCIP.templates.value'),
            POST_CHOMP   => 1
        }
    );

    my $output;
    $template->process( 'response.tt', $response, \$output, { binmode => ':encoding(utf8)' } );
    return $output;
}

1;
