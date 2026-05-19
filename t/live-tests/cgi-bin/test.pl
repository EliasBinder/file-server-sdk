#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI qw(:standard);
use FileServerSdk::Client;

binmode( STDOUT, ":utf8" );

my $action = CGI::param('ACTION') || 'html';
my $client = FileServerSdk::Client->new();

if ( $action eq 'html' ) {
    serve_html();
    return 1;
}
elsif ( $action eq 'generate_presigned_urls' ) {
    $client->handle_generate_presigned_urls("test");
    return 1;
}
elsif ( $action eq 'webhook' ) {
    $client->handle_webhook();
    return 1;
}
elsif ( $action eq 'form_submit' ) {
    print "Content-type: text/plain; charset=UTF-8\n\n";
    print "Unknown action: $action";
}
else {
    print "Content-type: text/plain; charset=UTF-8\n\n";
    print "Unknown action: $action";
}

sub serve_html {
    print "Content-type: text/html; charset=UTF-8\n\n";
    print "<html charset='UTF-8'><body>";

    my $content = qq$
    <h1>S3 Upload Test</h1>
    <p>Hier können Dateien direkt in einen S3 Bucket hochgeladen werden, ohne dass sie über den Primus Server laufen müssen. Es wird ein Pre-Signed URL generiert, mit dem die Datei direkt in den Bucket hochgeladen werden kann.</p>
    <form id="uploadForm" style="height: 450px">
        <fs-dropzone action-name="ACTION"></fs-dropzone>
        <input type="submit" value="Upload to S3" style="margin-top: 40px" />
    </form>
    <script type="module" src="https://cdn.jsdelivr.net/gh/EliasBinder/file-server-dropzone\@main/dist/fsdropzone.es.js?v=1.0.5"></script>
    $;
    print $content;

    print "</body></html>";

    1;
}
