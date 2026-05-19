# Getting Started Guide

Welcome to the File Server SDK! This guide will help you get up and running quickly.

## Prerequisites

- Perl 5.10 or higher
- Access to a File Server instance with pipeline management
- S3-compatible storage credentials
- Network access to the pipeline and metadata endpoints

## Installation

### Quick Install

```bash
git clone git@github.com:EliasBinder/file-server-sdk.git
cd file-server-sdk
perl Makefile.PL
make install
```

### Development Mode

If you're developing the SDK itself:

```bash
git clone git@github.com:EliasBinder/file-server-sdk.git
cd file-server-sdk
perl Makefile.PL
make
```

Then add the `lib` directory to your Perl path:

```bash
export PERL5LIB="/path/to/file-server-sdk/lib:$PERL5LIB"
```

## Environment Setup

The SDK requires three environment variables for authentication. Add these to your shell profile or application startup:

### Required Variables

```bash
export ACCESS_KEY_ID="your_api_key"
export SECRET_ACCESS_KEY="your_api_secret"
export PIPELINE_SHARED_SECRET="your_pipeline_shared_secret"
```

### Optional Variables

```bash
# S3 Host (defaults to s3.primuss.de)
export S3_HOST="s3.example.com"

# Pipeline Management Endpoint
export PIPELINE_ENDPOINT="https://pipeline-mgm.example.com/pipeline"

# Metadata Endpoint
export METADATA_ENDPOINT="https://pipeline-mgm.example.com/metadata"
```

## First Steps

### 1. Create a Simple Client

```perl
#!/usr/bin/perl
use strict;
use warnings;
use FileServerSdk::Client;

# Create a client instance
my $client = FileServerSdk::Client->new();

print "Client initialized successfully!\n";
```

### 2. Upload a File

```perl
use FileServerSdk::Client;

my $client = FileServerSdk::Client->new();

# Read a file
open(my $fh, '<', 'path/to/file.pdf') or die "Cannot open file: $!";
my $content = do { local $/; <$fh> };
close($fh);

# Upload to S3
$client->upload_file('my-bucket', 'documents/file.pdf', $content);

print "File uploaded successfully!\n";
```

### 3. Execute a Simple Pipeline

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

# Create a PDF merger task
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => [
        'my-bucket/file1.pdf',
        'my-bucket/file2.pdf'
    ],
    output_file => 'my-bucket/merged.pdf'
);

# Create a pipeline
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

# Execute the pipeline
my $pipeline_id = $client->execute_pipeline($pipeline);

print "Pipeline executed with ID: $pipeline_id\n";
```

## Common Use Cases

### File Upload and Processing

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';

# Upload files
my @files = ('document1.pdf', 'document2.pdf');
my @uploaded_files;

foreach my $file (@files) {
    open(my $fh, '<', $file) or die "Cannot open $file: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    my $key = "uploads/$file";
    $client->upload_file($bucket, $key, $content);
    push @uploaded_files, "$bucket/$key";
}

# Create a pipeline to merge them
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => \@uploaded_files,
    output_file => "$bucket/output/merged.pdf"
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

my $pipeline_id = $client->execute_pipeline($pipeline);
print "Pipeline ID: $pipeline_id\n";
```

### Browser-Based File Upload

For a web application allowing users to upload files directly to S3:

```perl
#!/usr/bin/perl
use CGI qw/:standard -utf8/;
use FileServerSdk::Client;
use JSON;

my $action = param('action');
my $client = FileServerSdk::Client->new();

if ($action eq 'get_upload_urls') {
    my $files_json = param('files');
    my $json = JSON->new->allow_nonref;
    my $files = $json->decode($files_json);
    
    # Generate presigned URLs
    my $urls = $client->handle_generate_presigned_urls(
        'my-bucket',
        {
            max_files => 5,
            min_files => 1,
            expires_in => 3600,
            content_types => [
                { type => 'application/pdf', limit => 20 }
            ]
        }
    );
    
    print header('application/json');
    print $json->encode($urls);
}
```

## Troubleshooting

### "ACCESS_KEY_ID environment variable is required"

Make sure you've set the required environment variables:

```bash
export ACCESS_KEY_ID="your_api_key"
export SECRET_ACCESS_KEY="your_api_secret"
export PIPELINE_SHARED_SECRET="your_pipeline_shared_secret"
```

### Connection Timeout

Check that you can reach the server endpoints:

```bash
# Test S3 connectivity
curl -I https://s3.primuss.de

# Test pipeline endpoint
curl -I https://pipeline-mgm.primuss.de/pipeline
```

### Permission Denied

Verify your API credentials are correct and have the necessary permissions.

## Next Steps

- Read the [Pipelines Guide](pipelines.md) to learn about building complex workflows
- Check out [Examples](examples.md) for real-world use cases
- Explore the [API Reference](api-reference.md) for detailed method documentation
