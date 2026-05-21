#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI qw(:standard);
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

binmode( STDOUT, ":utf8" );

# Print headers FIRST, before any other output
print "Content-type: text/plain; charset=UTF-8\n\n";

print
"Starting pipeline with webhook test... Make sure the webhook is reachable from outside.\n";

my $client = FileServerSdk::Client->new();

my $action = param('action') || 'execute';

if ( $action eq 'send' ) {
    my $pipeline       = FileServerSdk::SequentialPipeline->new();
    my $merge_pdf_task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ "test/sample1.pdf", "test/sample2.pdf" ],
        output_file => "test/merged_with_perl.pdf"
    );
    $pipeline->add_task_step($merge_pdf_task);

    print "Pipeline created successfully. Configuration:\n";
    my $json = $pipeline->to_json();

    # Print the JSON configuration of the pipeline
    use Data::Dumper;
    print Dumper($json);

    my $result = $client->execute_pipeline(
        $pipeline,
"https://plunder-gopher-concert.ngrok-free.dev/cgi-bin/pipeline_with_webhook.pl?action=webhook",
        sub {
            my ($response) = @_;
            print "Pipeline executed successfully\n";

            # Write something to STDERR to confirm that the webhook was called
            warn "Webhook callback received response: " . Dumper($response);

            print Dumper($response);
        },
        sub {
            my ($error) = @_;
            print "Pipeline execution failed\n";
            warn "Webhook callback received error: " . Dumper($error);
            print Dumper($error);
        }
    );

    print "Pipeline fired!\n";
}
elsif ( $action eq 'webhook' ) {
    $client->handle_webhook();
}
else {
    print "Unknown action: $action\n";
}
