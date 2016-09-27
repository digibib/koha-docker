#!/usr/bin/perl -w
#
# This cronjob processes pending print messages in message_queue by:
# - getting all messages, groups them by patrons
# - for each patron, convert messages to html and then to pdf
# - then create SOAP object to send to print service
use Modern::Perl;
use strict;
use warnings;

BEGIN {
    # find Koha's Perl modules
    use FindBin;
    eval { require "$FindBin::Bin/usr/share/koha/bin/kohalib.pl" };
}

use CGI qw( utf8 ); # NOT a CGI script, this is just to keep C4::Templates::gettemplate happy
use C4::Context qw( ouput_pref );
use C4::Letters qw( GetPrintMessages );
use C4::Templates qw( gettemplate );
use C4::Log qw( cronlogaction );
use Getopt::Long;

use File::Temp qw( tmpnam );
use Clone qw( clone);
use PDF::FromHTML;
use Data::Dumper;
use Koha::DateUtils;
use SOAP::Lite;
use MIME::Lite;
use MIME::Entity;
use MIME::Base64 qw( encode_base64 );

my ( $update_status, $print, $save, $url, $email, $user, $pass );

GetOptions(
    'update_status' => \$update_status,                 # set status to sent or failed
    'print'         => \$print,                         # send to print service
    'save'          => \$save,                          # save as pdf and html
    'e|email=s'     => \$email,                         # send attachments to this email
    'url=s'         => \$url  || $ENV{'PIDGEON_URL'},   # url of print service
    'u|user=s'      => \$user || $ENV{'PIDGEON_USER'},  # username of print service
    'p|pass=s'      => \$pass || $ENV{'PIDGEON_PASS'},  # password of print service
);

cronlogaction();

my $today_iso     = output_pref( { dt => dt_from_string, dateonly => 1, dateformat => 'iso' } ) ;
my $today_syspref = output_pref( { dt => dt_from_string, dateonly => 1 } );
my @all_messages = @{ &GetPrintMessages() };
my $sorted = group_messages_by_patrons(\@all_messages);
my $client = init_client() if $print;
assemble_birds($sorted);

sub init_client {
    my $auth = 'Basic '.encode_base64("$user:$pass");
    my $client = SOAP::Lite
        ->on_action( sub { return '""';})
        ->ns( 'http://www.ks.no/svarut/services', 'tns' )
        ->proxy( $url );
    $client->transport->http_request->header('Authorization' => $auth);
    return $client;
}

sub assemble_birds {
    my $patrons = shift;
    # run messages for each patron
    while ( my ($patron, $messages) = each %{ $patrons } )
    {
        my $docs = generate_html_from_patron_messages({messages => $messages});
        my ($html, $pdf)  = generate_pdf($docs);
        if ($email) {
            send_to_mail({
                to   => $email,
                from => C4::Context->preference('KohaAdminEmailAddress'),
                pdf  => $pdf,
                html => $html
            });
        }
        if ($print) {
            my $receiver = Koha::Patrons->find($patron);
            if (validate_destination($receiver)) {
                my $pidgeon  = feed_pidgeon($pdf, $receiver);
                warn Dumper(SOAP::Serializer->envelope(freeform => $pidgeon));
                my $res = send_pidgeon($pidgeon);
                warn Dumper($res->body);
                if ($res->fault) {
                    update_status($messages, 'failed');
                    warn $res->fault->faultstring
                } else {
                    update_status($messages, 'sent');
                }
            } else {
                warn "Invalid receiver address! Borrowernumber: " . $receiver->borrowernumber;
                $receiver->set({gonenoaddress => 1});
                $receiver->store;
                update_status($messages, 'failed');
            }
        }
    }
}

sub feed_pidgeon {
    my ( $pdf, $receiver ) = @_;

    my $pidgeon = SOAP::Data->name(
        'forsendelse' => \SOAP::Data->value(
            SOAP::Data->name( 'tittel'          => 'Test av brevdue' )->type( 'string' ),
            SOAP::Data->name( 'avgivendeSystem' => 'ITAS' )->type( 'string' ),
            SOAP::Data->name( 'konteringskode'  => 'deichman001' )->type( 'string' ),
            SOAP::Data->name( 'krevNiva4Innlogging'  => 0 )->type( 'xsd:boolean' ),
            SOAP::Data->name( 'kryptert'  => 0 )->type( 'xsd:boolean' ),
            SOAP::Data->name( 'kunDigitalLevering'  => 0 )->type( 'xsd:boolean' ),
            SOAP::Data->name(
                'printkonfigurasjon' => \SOAP::Data->value(
                    SOAP::Data->name( 'fargePrint'  => 0 )->type( 'xsd:boolean' ),
                    SOAP::Data->name( 'tosidig'  => 0 )->type( 'xsd:boolean' ),
                    SOAP::Data->name( 'brevtype'  => 'BPOST' )->type( 'tns:brevtype' ),
                ),
            )->type('tns:printKonfigurasjon'),
            SOAP::Data->name(
                'mottaker' => \SOAP::Data->value(
                    SOAP::Data->name( 'navn'      => $receiver->firstname . " " . $receiver->surname )->type( 'string' ),
                    SOAP::Data->name( 'adresse1'  => $receiver->address)->type( 'string' ),
                    SOAP::Data->name( 'adresse2'  => $receiver->address2 )->type( 'string' ),
                    SOAP::Data->name( 'postnr'    => $receiver->zipcode )->type( 'string' ),
                    SOAP::Data->name( 'poststed'  => $receiver->city )->type( 'string' ),
                    SOAP::Data->name( 'fodselsnr' => "00000000000" )->type( 'string' ),
                ),
            )->type('tns:privatPerson'),
            SOAP::Data->name(
               'dokumenter' => \SOAP::Data->value(
                   SOAP::Data->name( 'filnavn'   => "testdokument" )->type( 'string' ),
                   SOAP::Data->name( 'mimetype'  => "application/pdf" )->type( 'string' ),
                   SOAP::Data->name( 'data'      => SOAP::Data->type(base64 => $pdf))->type( 'xs:base64Binary'),
               ),
            ),
        )
    );
    return $pidgeon;
}

sub send_pidgeon {
    my $message = shift;
    my $res = $client->sendForsendelse( $message );
    return $res;
}

sub validate_destination {
    my $receiver = shift;

    return 0 if $receiver->surname eq '';
    return 0 if $receiver->address eq '';
    return 0 if $receiver->city eq '';
    return 0 unless $receiver->zipcode =~ /^\d{4}$/;

    return 1;
}

sub update_status {
    my ($messages, $status) = @_;

    return unless $update_status;
    foreach my $message ( @{$messages} ) {
        C4::Letters::_set_message_status({
            message_id => $message->{'message_id'},
            status => $status
        });
    }
}

sub group_messages_by_patrons {
    my $messages = shift;
    my %grouped;
    for (@{$messages} ) {
       push @{ $grouped{$_->{borrowernumber}} }, $_; 
    }
    return \%grouped
}

# patron filtered messages
sub generate_html_from_patron_messages {
    my ( $params ) = @_;
    my $messages = $params->{messages};

    my $template = C4::Templates::gettemplate( 'batch/print-notices.tt', 'intranet', new CGI );

    $template->param(
        stylesheet => C4::Context->preference("NoticeCSS"),
        today      => $today_syspref,
        messages   => $messages,
    );

    return $template->output;
}

sub generate_pdf {
    my $html = shift;
    my $PDF = PDF::FromHTML->new( encoding => 'utf-8' );
    
    $PDF->load_file(\$html);
    $PDF->convert;
    if ($save) {
        # Need to clone PDF object so we don't empty it by saving
        my $clone = clone($PDF);
        save_html($html);
        save_pdf($clone);
    }

    # Convert to string scalar to use as attachment
    my $pdf = '';
    $PDF->write_file(\$pdf);

    return ($html, $pdf);
}

sub save_html {
    my $html = shift;
    my $file = tmpnam() . '.html';
    open my $html_fh, '>:encoding(utf8)', $file or die "Cannot save html file";
    say $html_fh $html;
    close $html_fh;
}

sub save_pdf {
    my $pdf = shift;
    my $file = tmpnam() . '.pdf';
    $pdf->write_file( $file );
}


sub send_to_mail {
    my ( $params ) = @_;
    my $to = $params->{to};
    my $from = $params->{from};
    return unless $to and $from;

    my $mail = MIME::Lite->new(
        From     => $from,
        To       => $to,
        Subject  => 'Brevduer sendt ' . $today_syspref,
        Type     => 'multipart/mixed',
    );
    $mail->attach(
        Type => 'application/pdf',
        Data => $params->{pdf}
    );
    $mail->attach(
        Type => 'text/html',
        Data => $params->{html}
    );

    $mail->send;
}

1;
