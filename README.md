# File Server SDK (Perl)

A powerful Perl SDK for interacting with the File Server and Pipeline management system. Build complex file processing pipelines with support for sequential and parallel execution.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Testing](#testing)
- [Requirements](#requirements)

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

### 2. Setup the Client

```perl
use FileServerSdk::Client;

my $client = FileServerSdk::Client->new();
```

### 3. Use Net::Amazon::S3 Client directly if needed:

```perl
my $s3_client = $client->s3();

# Use $s3_client for direct S3 operations if necessary
```

### 5. Allow a browser to upload files to S3 using a presigned URL:

```perl
use FileServerSdk::Client;

# Initialize client
my $client = FileServerSdk::Client->new();

# For the JS, import the modified dropzone with S3 support (coming soon)

# In your Perl module, call $client->handle_webhook() to process incoming webhook requests when the given webhook URL is hit by the pipeline server:
my $action = CGP::param('action'); # 'success' or 'error'
if ($action eq 'generate_presigned_urls') {
  my @file_placeholders = $client->handle_generate_presigned_urls(
    bucket => 'your_bucket_name',
    content_types => ['application/pdf', 'image/jpeg'], # Optional, specify allowed content types
    num_files => 5, # Optional, specify max number of presigned URLs to generate
    expires_in => 3600 # Optional, specify expiration time in seconds (default 1 hour)
  );

  # E.g. Start a pipeline with the generated presigned URLs as input files, etc.
}
```

### 4. Create a Simple Pipeline for Merging PDFs and other file processing tasks:

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

### 5. Execute a Pipeline with Webhooks (Get the final result of the pipeline execution)

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

# In your Perl module, call $client->handle_webhook() to process incoming webhook requests when the given webhook URL is hit by the pipeline server:
my $action = CGP::param('action'); # 'success' or 'error'
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

### Pipelines

The SDK provides two types of pipelines for different execution patterns:

#### SequentialPipeline

Executes tasks one after another in order.

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2)
    ->add_task_step($task3);
```

#### ParallelPipeline

Executes multiple sequential pipelines concurrently.

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

### FileServerSdk::Client

#### Constructor

```perl
my $client = FileServerSdk::Client->new(%args);
```

**Parameters:**
- Custom arguments can be passed and stored for later use

**Environment Variables Required:**
- `ACCESS_KEY_ID` - AWS-like access key
- `SECRET_ACCESS_KEY` - AWS-like secret key
- `PIPELINE_SHARED_SECRET` - Shared secret for webhook verification

**Example:**

```perl
my $client = FileServerSdk::Client->new(
    custom_option => 'value'
);
```

#### Methods

##### `s3([$s3_client])`

Get or set the S3 client.

```perl
# Get S3 client
my $s3 = $client->s3();

# Set S3 client
$client->s3($new_s3_client);
```

##### `execute_pipeline($pipeline, [$webhook_url, $on_success, $on_error])`

Execute a pipeline.

**Parameters:**
- `$pipeline` - SequentialPipeline or ParallelPipeline object (required)
- `$webhook_url` - URL for webhook callbacks (optional, but required if callbacks provided)
- `$on_success` - Code reference for success callback (required if webhook_url provided)
- `$on_error` - Code reference for error callback (required if webhook_url provided)

**Returns:** Pipeline ID (string)

**Example - Without Webhook:**

```perl
my $pipeline_id = $client->execute_pipeline($pipeline);
```

**Example - With Webhook:**

```perl
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://example.com/webhook',
    sub { print "Success!\n"; },
    sub { my ($err) = @_; print "Error: $err\n"; }
);
```

##### `handle_webhook()`

Handle incoming webhook requests.

**Returns:** 1 on success, 0 on failure

**Example:**

```perl
# In your webhook endpoint
my $result = $client->handle_webhook();
if ($result) {
    print "Webhook processed\n";
}
```

##### `handle_generate_presigned_urls($bucket, [$content_types, $num_files, $expires_in, $on_finish])`

Generate presigned URLs for S3 uploads. Reads file information from CGI parameters and generates signed URLs.

**Parameters:**
- `$bucket` - S3 bucket name (required)
- `$content_types` - Array reference of allowed MIME types (optional)
- `$num_files` - Expected number of files (optional)
- `$expires_in` - URL expiration time in seconds (optional, default 3600)
- `$on_finish` - Code reference callback when finished (optional)

**Returns:** 1 on success, 0 on failure

**Example:**

```perl
# Generate presigned URLs for file uploads
my $result = $client->handle_generate_presigned_urls(
    bucket => 'my-bucket',
    content_types => ['application/pdf', 'image/jpeg'],
    num_files => 5,
    expires_in => 7200,
    on_finish => sub {
        my ($presigned_urls) = @_;
        # Handle generated URLs
    }
);

if ($result) {
    print "Presigned URLs generated\n";
}
```

**Expected CGI Parameters:**
- `files` - JSON array of file objects with `index` and `content_type` properties

### FileServerSdk::SequentialPipeline

#### Constructor

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new(%args);
```

#### Methods

##### `add_task_step($task)`

Add a task step to the pipeline.

**Parameters:**
- `$task` - Task object with `to_json()` method (required)

**Returns:** Self (for method chaining)

**Example:**

```perl
$pipeline->add_task_step($task1)
         ->add_task_step($task2);
```

##### `add_parallel_pipeline_step($parallel_pipeline)`

Add a parallel pipeline as a step.

**Parameters:**
- `$parallel_pipeline` - ParallelPipeline object (required)

**Returns:** Self (for method chaining)

**Example:**

```perl
$pipeline->add_parallel_pipeline_step($parallel);
```

##### `get_steps()`

Retrieve all steps in the pipeline.

**Returns:** List of step objects

**Example:**

```perl
my @steps = $pipeline->get_steps();
print "Pipeline has " . scalar(@steps) . " steps\n";
```

##### `to_json()`

Serialize the pipeline to JSON format.

**Returns:** Hash reference

**Example:**

```perl
my $json = $pipeline->to_json();
# Returns: { 0 => {...}, 1 => {...}, ... }
```

### FileServerSdk::ParallelPipeline

#### Constructor

```perl
my $parallel = FileServerSdk::ParallelPipeline->new(%args);
```

#### Methods

##### `add_sequential_pipeline($pipeline)`

Add a sequential pipeline to run in parallel.

**Parameters:**
- `$pipeline` - SequentialPipeline object (required)

**Returns:** Self (for method chaining)

**Example:**

```perl
$parallel->add_sequential_pipeline($seq1)
         ->add_sequential_pipeline($seq2);
```

##### `get_steps()`

Retrieve all sequential pipelines.

**Returns:** List of SequentialPipeline objects

##### `to_json()`

Serialize the parallel pipeline to JSON.

**Returns:** Array reference

**Example:**

```perl
my $json = $parallel->to_json();
# Returns: [step0, step1, ...]
```

### FileServerSdk::Tasks::PdfMergerTask

#### Constructor

```perl
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => \@files,
    output_file => $output_name
);
```

**Parameters:**
- `input_files` - Array reference of input file names (required, non-empty)
- `output_file` - Output file name (required)

**Example:**

```perl
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['doc1.pdf', 'doc2.pdf'],
    output_file => 'combined.pdf'
);
```

#### Methods

##### `input_files()`

Get the input files.

**Returns:** Array reference

##### `output_file()`

Get the output file name.

**Returns:** String

##### `to_json()`

Serialize the task to JSON.

**Returns:** Hash reference with structure:
```perl
{
    type       => 'pdf_merger',
    inputFiles => [...],     # Array reference of input file names
    outputFile => '...'      # Output file name
}
```

## Examples

### Example 1: Simple PDF Merge

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

# Set environment variables first
$ENV{ACCESS_KEY_ID}           = 'your_key';
$ENV{SECRET_ACCESS_KEY}       = 'your_secret';
$ENV{PIPELINE_SHARED_SECRET}  = 'your_shared_secret';

my $client = FileServerSdk::Client->new();

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['report_2024.pdf', 'appendix.pdf'],
    output_file => 'final_report.pdf'
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

my $pipeline_id = $client->execute_pipeline($pipeline);
print "Pipeline submitted: $pipeline_id\n";
```

### Example 2: Sequential Pipeline with Multiple Tasks

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

# Create multiple tasks
my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['part1_a.pdf', 'part1_b.pdf'],
    output_file => 'part1_merged.pdf'
);

my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['part2_a.pdf', 'part2_b.pdf'],
    output_file => 'part2_merged.pdf'
);

# Chain tasks in sequential pipeline
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2);

my $pipeline_id = $client->execute_pipeline($pipeline);
print "Sequential pipeline ID: $pipeline_id\n";
```

### Example 3: Parallel Pipelines

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::ParallelPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

# Create two independent sequential pipelines
my $seq1 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['batch1_a.pdf', 'batch1_b.pdf'],
            output_file => 'batch1_output.pdf'
        )
    );

my $seq2 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['batch2_a.pdf', 'batch2_b.pdf'],
            output_file => 'batch2_output.pdf'
        )
    );

# Execute both in parallel
my $parallel = FileServerSdk::ParallelPipeline->new()
    ->add_sequential_pipeline($seq1)
    ->add_sequential_pipeline($seq2);

my $pipeline_id = $client->execute_pipeline($parallel);
print "Parallel pipeline ID: $pipeline_id\n";
```

### Example 4: Complex Nested Pipelines

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::ParallelPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

# Create parallel pipelines with multiple tasks each
my $seq1 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['a1.pdf', 'a2.pdf', 'a3.pdf'],
            output_file => 'a_output.pdf'
        )
    )
    ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['a_output.pdf'],
            output_file => 'a_final.pdf'
        )
    );

my $seq2 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['b1.pdf', 'b2.pdf'],
            output_file => 'b_output.pdf'
        )
    );

my $parallel = FileServerSdk::ParallelPipeline->new()
    ->add_sequential_pipeline($seq1)
    ->add_sequential_pipeline($seq2);

# Add parallel pipeline as step in main sequential pipeline
my $main_pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_parallel_pipeline_step($parallel)
    ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['a_final.pdf', 'b_output.pdf'],
            output_file => 'final_combined.pdf'
        )
    );

my $pipeline_id = $client->execute_pipeline($main_pipeline);
print "Complex pipeline ID: $pipeline_id\n";
```

### Example 5: With Webhook Callbacks

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['input1.pdf', 'input2.pdf'],
    output_file => 'output.pdf'
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

# Execute with webhook callbacks
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://my-server.com/webhook',
    sub {
        # Success callback
        print "Pipeline $pipeline_id completed successfully!\n";
        # Handle success logic here
    },
    sub {
        my ($error) = @_;
        # Error callback
        print "Pipeline $pipeline_id failed: $error\n";
        # Handle error logic here
    }
);

print "Pipeline ID: $pipeline_id\n";
```

## Testing

The SDK includes a comprehensive test suite with 50+ test suites and 200+ assertions covering:

- Unit tests for each module
- Integration tests for complete workflows
- Edge case handling
- Error scenarios
- Validation checks

### Running Tests

```bash
cd file-server-sdk

# Run all tests
prove t/

# Run specific test file
prove t/01_client.t

# Verbose output
prove -v t/

# Run with detailed output
perl -Ilib t/01_client.t
```

### Test Files

- `t/01_client.t` - Client class tests
- `t/02_sequential_pipeline.t` - Sequential pipeline tests
- `t/03_parallel_pipeline.t` - Parallel pipeline tests
- `t/04_pdf_merger_task.t` - PDF merger task tests
- `t/05_integration.t` - Integration tests
- `t/README.md` - Detailed test documentation

See `t/README.md` for comprehensive test documentation.

## Requirements

### System Requirements

- Perl 5.14 or higher
- Standard Perl modules (Test::More for testing)

### Dependencies

The SDK requires the following Perl modules:

- `Net::Amazon::S3` - S3 client integration
- `Net::Amazon::S3::Authorization::Basic` - S3 authorization
- `Net::Amazon::S3::Vendor::Generic` - Generic S3 vendor support
- `JSON` - JSON encoding/decoding
- `HTTP::Tiny` - HTTP client
- `CGI` - CGI parameter handling

### Environment Variables

Three environment variables are required for authentication:

- `ACCESS_KEY_ID` - AWS-like access key ID
- `SECRET_ACCESS_KEY` - AWS-like secret access key
- `PIPELINE_SHARED_SECRET` - Shared secret for webhook verification

## Configuration

### Custom S3 Host

```bash
export S3_HOST="s3.custom-domain.de"
```

### Custom Pipeline Endpoint

```bash
export PIPELINE_ENDPOINT="https://custom-pipeline.example.com/pipeline"
```

### Default Presigned URL Expiration

Default expiration for presigned URLs is 1 hour (3,600 seconds).

## Error Handling

The SDK throws exceptions for validation errors. Always wrap SDK calls in eval blocks:

```perl
my $client = eval {
    FileServerSdk::Client->new();
};

if ($@) {
    die "Failed to create client: $@";
}
```

### Common Errors

**Missing Environment Variables:**
```
ACCESS_KEY_ID environment variable is required
SECRET_ACCESS_KEY environment variable is required
PIPELINE_SHARED_SECRET environment variable is required
```

**Invalid Pipeline Parameters:**
```
pipeline is required
step is required
input_files is required
output_file is required
```

**Type Validation:**
```
input_files must be an array reference
input_files cannot be empty
pipeline must have a to_json method
```

## Best Practices

### 1. Error Handling

Always check for errors and handle them appropriately:

```perl
my $pipeline_id = eval {
    $client->execute_pipeline($pipeline);
};

if ($@) {
    warn "Pipeline execution failed: $@";
    # Handle error
}
```

### 2. Environment Configuration

Set environment variables in a configuration file or CI/CD system:

```bash
# .env file (load with dotenv or similar)
ACCESS_KEY_ID="your_key"
SECRET_ACCESS_KEY="your_secret"
PIPELINE_SHARED_SECRET="your_shared_secret"
```

### 3. Reuse Clients

Create a client once and reuse it for multiple operations:

```perl
my $client = FileServerSdk::Client->new();

# Reuse for multiple pipeline executions
my $id1 = $client->execute_pipeline($pipeline1);
my $id2 = $client->execute_pipeline($pipeline2);
```

### 4. Method Chaining

Use method chaining for cleaner code:

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2)
    ->add_task_step($task3);
```

### 5. Large File Lists

When dealing with many files, build the array incrementally:

```perl
my @files;
for my $i (1..100) {
    push @files, "document_$i.pdf";
}

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => \@files,
    output_file => 'merged.pdf'
);
```

## Performance Considerations

- **Pipeline Execution**: Parallel pipelines execute sequentially in the server; concurrency depends on server-side implementation
- **File Limits**: No hard limit on input files, but validate based on your use case
- **Webhook Timeouts**: Ensure webhook endpoints respond quickly
- **Memory Usage**: Large pipelines are serialized to JSON; consider memory for complex structures

## Troubleshooting

### Pipeline Execution Fails

1. Verify all environment variables are set correctly
2. Check that the pipeline server is accessible
3. Validate pipeline JSON structure with `to_json()`
4. Check webhook endpoint is accessible if using callbacks

### Webhook Not Received

1. Verify webhook URL is publicly accessible
2. Check firewall/security group rules
3. Verify `PIPELINE_SHARED_SECRET` matches on both ends
4. Check server logs for HTTP errors

### S3 Connection Issues

1. Verify `ACCESS_KEY_ID` and `SECRET_ACCESS_KEY`
2. Check S3 host configuration
3. Ensure network connectivity to S3

**Version:** 1.0.0  
**Last Updated:** 2026
**Author:** Elias Binder  
**Repository:** https://github.com/yourusername/file-server-sdk
