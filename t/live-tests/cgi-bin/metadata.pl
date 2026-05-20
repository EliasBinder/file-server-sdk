#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI qw(:standard);
use FileServerSdk::Client;

binmode( STDOUT, ":utf8" );

# Print headers FIRST, before any other output
print "Content-type: text/plain; charset=UTF-8\n\n";

print "Starting metadata test...\n";

my $client = FileServerSdk::Client->new();

my $file_content = "This is a test file for upload and download.";
$client->upload_file( "test", "test_upload.txt", $file_content, "text/plain" );
print "File under test uploaded successfully.\n";

my $metadata = $client->get_metadata( "test", "test_upload.txt" );
print "Metadata retrieved successfully. Metadata:\n";
foreach my $key ( keys %$metadata ) {
    print "$key: $metadata->{$key}\n";
}

print "Setting metadata 'key1' to 'value1' and 'key2' to 'value2'...\n";
$client->set_metadata( "test", "test_upload.txt",
    { key1 => 'value1', key2 => 'value2' } );
print "Metadata set successfully.\n";

my $updated_metadata = $client->get_metadata( "test", "test_upload.txt" );
print "Updated metadata retrieved successfully. Updated Metadata:\n";
foreach my $key ( keys %$updated_metadata ) {
    print "$key: $updated_metadata->{$key}\n";
}

if (   defined $updated_metadata->{key1}
    && $updated_metadata->{key1} eq 'value1'
    && defined $updated_metadata->{key2}
    && $updated_metadata->{key2} eq 'value2' )
{
    print "Metadata test successful. Metadata values match expected values.";
}
else {
    print "Metadata test failed. Metadata values do not match expected values.";
}
