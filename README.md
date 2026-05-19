# File Server SDK (Perl)

A powerful Perl SDK for interacting with the File Server and Pipeline management system. Build complex file processing pipelines with support for sequential and parallel execution.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [API Reference](#api-reference)
- [Features](#features)
- [Testing](#testing)
- [Requirements](#requirements)
- [Documentation](#documentation)

## Installation

### Via CPAN

```bash
cpan https://github.com/EliasBinder/file-server-sdk.git
```

### Manual Installation

```bash
git clone git@github.com:EliasBinder/file-server-sdk.git
cd file-server-sdk
perl Makefile.PL
make
make test
make install
```

### Development Setup

```bash
git clone git@github.com:EliasBinder/file-server-sdk.git
cd file-server-sdk
perl Makefile.PL
make
```

## Quick Start

### 1. Set Environment Variables

The SDK requires three environment variables for authentication:

```bash
export ACCESS_KEY_ID="your_api_key"
export SECRET_ACCESS_KEY="your_api_secret"
export PIPELINE_SHARED_SECRET="your_pipeline_shared_secret"
```

Optionally, configure server endpoints:

```bash
export S3_HOST="s3.primuss.de"                              # Default
export PIPELINE_ENDPOINT="https://pipeline-mgm.primuss.de/pipeline"  # Default
export METADATA_ENDPOINT="https://pipeline-mgm.primuss.de/metadata"  # Default
```

### 2. Initialize the Client

```perl
use FileServerSdk::Client;

my $client = FileServerSdk::Client->new();
```

### 3. Access the S3 Client Directly

```perl
my $s3_client = $client->s3();

# Use $s3_client for direct S3 operations if necessary
```

### 4. Generate Presigned URLs for Browser Uploads

```perl
use FileServerSdk::Client;

my $client = FileServerSdk::Client->new();

# Handle presigned URL generation request
my $action = CGI::param('action');
if ($action eq 'generate_presigned_urls') {
  my $presigned_urls = $client->handle_generate_presigned_urls(
    'your_bucket_name',
    {
      content_types => [
        { type => 'application/pdf', limit => 20 },
        { type => 'image/jpeg', limit => 5 }
      ],
      max_files  => 10,
      min_files  => 1,
      expires_in => 3600  # 1 hour (default)
    }
  );

  # Use the presigned URLs to allow browser uploads
}
```

### 5. Create and Execute a Simple Pipeline

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

# Initialize client
my $client = FileServerSdk::Client->new();

# Create a task
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['bucket/document1.pdf', 'bucket/document2.pdf'],
    output_file => 'bucket/merged.pdf'
);

# Create a sequential pipeline with the task
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

# Execute the pipeline (without webhook)
my $pipeline_id = $client->execute_pipeline($pipeline);
print "Pipeline ID: $pipeline_id\n";
```

### 6. Execute a Pipeline with Webhook Callbacks

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['file1.pdf', 'file2.pdf'],
    output_file => 'output.pdf'
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

# Execute with webhook callbacks
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-server.com/some-path?action=webhook',
    sub {
        # Success callback
        print "Pipeline completed successfully!\n";
    },
    sub {
        my ($error) = @_;
        # Error callback
        print "Pipeline failed: $error\n";
    }
);

# Handle incoming webhook on your server
my $action = CGI::param('action');
if ($action eq 'webhook') {
  $client->handle_webhook();
}
```

## Core Concepts

### Client

The main entry point for interacting with the File Server API. Handles authentication, pipeline execution, and webhook management.

**Features:**
- S3 client integration
- Pipeline execution
- Webhook handling
- Presigned URL generation
- Callback management
- File operations (upload, download, delete)
- Metadata management

### Pipelines

The SDK provides two types of pipelines for different execution patterns:

#### SequentialPipeline

Executes tasks one after another in order. Each task starts only after the previous one completes.

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2)
    ->add_task_step($task3);
```

#### ParallelPipeline

Executes multiple sequential pipelines concurrently. Use this when you have independent workflows that should run in parallel.

```perl
my $seq1 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2);

my $seq2 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task3);

my $parallel = FileServerSdk::ParallelPipeline->new()
    ->add_sequential_pipeline($seq1)
    ->add_sequential_pipeline($seq2);
```

You can also nest pipelines:

```perl
my $seq_with_parallel = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_parallel_pipeline_step($parallel)
    ->add_task_step($task4);
```

### Tasks

Tasks represent individual file processing operations. Currently supported:

#### PdfMergerTask

Merges multiple PDF files into a single output file.

```perl
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['file1.pdf', 'file2.pdf', 'file3.pdf'],
    output_file => 'merged.pdf'
);
```

## API Reference

### Client Methods

#### `new()`

Creates a new client instance. Requires environment variables: `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, and `PIPELINE_SHARED_SECRET`.

```perl
my $client = FileServerSdk::Client->new();
```

#### `s3()`

Gets or sets the S3 client instance.

```perl
my $s3_client = $client->s3();
```

#### `download_file($bucket, $key)`

Downloads a file from S3.

```perl
my $content = $client->download_file('my_bucket', 'path/to/file.pdf');
```

#### `upload_file($bucket, $key, $content)`

Uploads content to S3.

```perl
$client->upload_file('my_bucket', 'path/to/file.pdf', $file_content);
```

#### `delete_file($bucket, $key)`

Deletes a file from S3.

```perl
$client->delete_file('my_bucket', 'path/to/file.pdf');
```

#### `get_metadata($bucket, $key)`

Retrieves metadata for a file.

```perl
my $metadata = $client->get_metadata('my_bucket', 'path/to/file.pdf');
```

#### `set_metadata($bucket, $key, $metadata)`

Sets metadata for a file.

```perl
$client->set_metadata('my_bucket', 'path/to/file.pdf', { key => 'value' });
```

#### `execute_pipeline($pipeline, [$webhook_url, $on_success, $on_error])`

Executes a pipeline. Optionally accepts webhook URL and callbacks.

```perl
# Without webhooks
my $pipeline_id = $client->execute_pipeline($pipeline);

# With webhooks
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-server.com/webhook',
    sub { print "Success!\n"; },
    sub { my ($error) = @_; print "Error: $error\n"; }
);
```

#### `handle_webhook()`

Processes incoming webhook requests from the pipeline server.

```perl
if ($action eq 'webhook') {
    $client->handle_webhook();
}
```

#### `handle_generate_presigned_urls($bucket, $config)`

Generates presigned URLs for browser-based S3 uploads.

```perl
my $urls = $client->handle_generate_presigned_urls(
    'my_bucket',
    {
        max_files => 10,
        min_files => 1,
        expires_in => 3600,
        content_types => [
            { type => 'application/pdf', limit => 20 },
            { type => 'image/jpeg', limit => 5 }
        ]
    }
);
```

#### `cleanup_pipeline($pipeline)`

Deletes all files associated with a pipeline.

```perl
$client->cleanup_pipeline($pipeline);
```

### Pipeline Methods

#### `SequentialPipeline->new()`

Creates a new sequential pipeline.

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new();
```

#### `add_task_step($task)`

Adds a task to the pipeline.

```perl
$pipeline->add_task_step($task);
```

#### `add_parallel_pipeline_step($parallel_pipeline)`

Adds a parallel pipeline as a step in a sequential pipeline.

```perl
$pipeline->add_parallel_pipeline_step($parallel);
```

#### `to_json()`

Converts the pipeline to JSON representation.

```perl
my $json = $pipeline->to_json();
```

#### `get_files()`

Returns all files referenced in the pipeline.

```perl
my @files = $pipeline->get_files();
```

### Task Methods

#### `PdfMergerTask->new(%options)`

Creates a new PDF merger task.

```perl
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['file1.pdf', 'file2.pdf'],
    output_file => 'merged.pdf'
);
```

## Features

- **S3 Integration**: Full integration with S3-compatible storage
- **Pipeline Management**: Build and execute complex file processing workflows
- **Sequential Execution**: Run tasks one after another
- **Parallel Execution**: Run independent workflows concurrently
- **Webhook Support**: Get notified when pipelines complete or fail
- **Presigned URLs**: Generate secure URLs for browser-based uploads
- **File Management**: Upload, download, and delete files
- **Metadata**: Get and set file metadata
- **Error Handling**: Comprehensive error handling and validation

## Testing

Run the test suite:

```bash
make test
```

## Requirements

- Perl 5.10+
- Net::Amazon::S3
- HTTP::Tiny
- JSON
- MIME::Base64
- Digest::HMAC_SHA1

## Documentation

Comprehensive documentation is available in the `docs` folder:

- [Getting Started](docs/getting-started.md) - Detailed setup and first steps
- [Architecture](docs/architecture.md) - System design and concepts
- [Pipelines](docs/pipelines.md) - Pipeline building and execution
- [Tasks](docs/tasks.md) - Available tasks and creating custom tasks
- [S3 Operations](docs/s3-operations.md) - File management and S3 integration
- [Webhooks](docs/webhooks.md) - Webhook handling and callbacks
- [Presigned URLs](docs/presigned-urls.md) - Browser-based file uploads
- [API Reference](docs/api-reference.md) - Complete API documentation
- [Examples](docs/examples.md) - Real-world usage examples
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## License

MIT License

## Author

Elias Binder
