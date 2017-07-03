package NCIP::Dancing;
use Dancer ':syntax';

our $VERSION = '0.1';

use NCIP;


any [ 'get', 'post' ] => '/' => sub {
    content_type 'application/xml';
    my $ncip = NCIP->new($ENV{NCIP_CONFIG_DIR} || 't/config_sample');
    my $xml  = param 'xml';
    if ( request->is_post ) {
        $xml = request->body;
    }
    debug $xml if config->{log_request_xml};

    my $content = $ncip->process_request($xml);
    debug $content if config->{log_response_xml};

    template 'main', { content => $content };
};

true;
