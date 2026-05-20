#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI qw(:standard);
use FileServerSdk::Client;

binmode( STDOUT, ":utf8" );

# Print headers FIRST, before any other output
print "Content-type: text/plain; charset=UTF-8\n\n";

print "Starting file deletion test...\n";

my $client = FileServerSdk::Client->new();

$client->delete_file( "test", "test_upload.txt" );
print
"File deletion attempted. If no errors were raised, the file was likely deleted successfully.\n";
