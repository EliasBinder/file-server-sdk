#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI qw(:standard);
use FileServerSdk::Client;

binmode( STDOUT, ":utf8" );

# Print headers FIRST, before any other output
print "Content-type: text/plain; charset=UTF-8\n\n";

print "Starting file upload and download test...\n";

my $client = FileServerSdk::Client->new();

my $file_content = "This is a test file for upload and download.";
$client->upload_file( "test", "test_upload.txt", $file_content, "text/plain" );
print "File uploaded successfully.\n";
my $downloaded_content = $client->download_file( "test", "test_upload.txt" );
print "File downloaded successfully. Content: $downloaded_content\n";

if ( defined $downloaded_content && $downloaded_content eq $file_content ) {
    print "File upload and download successful. Content matches.";
}
else {
    print "File upload and download failed. Content does not match.";
}
