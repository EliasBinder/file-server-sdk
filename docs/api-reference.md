# API Reference

Complete API documentation for the File Server SDK.

## FileServerSdk::Client

The main client class for interacting with the File Server.

### Constructor

#### `new(%args)`

Creates a new client instance. Requires environment variables to be set.

**Parameters:** None (uses environment variables)

**Returns:** FileServerSdk::Client instance

**Environment Variables Required:**
- `ACCESS_KEY_ID`: S3 access key
- `SECRET_ACCESS_KEY`: S3 secret key
- `PIPELINE_SHARED_SECRET`: Server authentication secret

**Environment Variables Optional:**
- `S3_HOST`: S3 endpoint (default: s3.primuss.de)
- `PIPELINE_ENDPOINT`: Pipeline server URL (default: https://pipeline-mgm.primuss.de/pipeline)
- `METADATA_ENDPOINT`: Metadata server URL (default: https://pipeline-mgm.primuss.de/metadata)

**Example:**
```perl
my $client = FileServerSdk::Client->new();
```

### File Operations

#### `upload_file($bucket, $key, $content)`

Uploads content to S3.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$key` (string, required): S3 object key (path)
- `$content` (string, required): File content to upload

**Returns:** 1 on success

**Throws:** Dies on error

**Example:**
```perl
$client->upload_file('my-bucket', 'documents/file.pdf', $content);
```

#### `download_file($bucket, $key)`

Downloads a file from S3.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$key` (string, required): S3 object key (path)

**Returns:** File content (string)

**Throws:** Dies on error

**Example:**
```perl
my $content = $client->download_file('my-bucket', 'documents/file.pdf');
```

#### `delete_file($bucket, $key)`

Deletes a file from S3.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$key` (string, required): S3 object key (path)

**Returns:** 1 on success

**Throws:** Dies on error

**Example:**
```perl
$client->delete_file('my-bucket', 'documents/file.pdf');
```

### Metadata Operations

#### `get_metadata($bucket, $key)`

Gets metadata for a file.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$key` (string, required): S3 object key (path)

**Returns:** Hashref containing metadata

**Throws:** Dies on error

**Example:**
```perl
my $metadata = $client->get_metadata('my-bucket', 'documents/file.pdf');
print $metadata->{author};
```

#### `set_metadata($bucket, $key, $metadata)`

Sets metadata for a file.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$key` (string, required): S3 object key (path)
- `$metadata` (hashref, required): Metadata to set

**Returns:** 1 on success

**Throws:** Dies on error

**Example:**
```perl
$client->set_metadata('my-bucket', 'documents/file.pdf', {
    author => 'John Doe',
    category => 'reports'
});
```

### Pipeline Operations

#### `execute_pipeline($pipeline, [$webhook_url, $on_success, $on_error])`

Executes a pipeline.

**Parameters:**
- `$pipeline` (object, required): SequentialPipeline or ParallelPipeline instance
- `$webhook_url` (string, optional): URL for webhook callbacks
- `$on_success` (code ref, optional): Success callback (required if webhook_url provided)
- `$on_error` (code ref, optional): Error callback (required if webhook_url provided)

**Returns:** Pipeline ID (string)

**Throws:** Dies on error

**Callback Signatures:**
- Success: `sub { }` (no parameters)
- Error: `sub { my ($error) = @_; }` (error message parameter)

**Example:**
```perl
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-app.com/webhook?action=webhook',
    sub { print "Success!\n"; },
    sub { my ($e) = @_; print "Error: $e\n"; }
);
```

#### `handle_webhook()`

Handles incoming webhook callbacks. Should be called from your webhook handler.

**Parameters:** None (uses CGI parameters)

**Returns:** 1 on success, 0 on failure

**CGI Parameters Expected:**
- `secret`: Shared secret (validated automatically)
- `pipelineId`: Pipeline ID
- `status`: Pipeline status (e.g., 'completed')
- `error`: Error message (if status indicates failure)

**Example:**
```perl
if ($action eq 'webhook') {
    my $result = $client->handle_webhook();
    if ($result) {
        print "Webhook processed successfully\n";
    } else {
        print "Webhook processing failed\n";
    }
}
```

#### `cleanup_pipeline($pipeline)`

Deletes all files associated with a pipeline.

**Parameters:**
- `$pipeline` (object, required): SequentialPipeline or ParallelPipeline instance

**Returns:** None

**Throws:** Warnings on individual file deletion failures

**Example:**
```perl
$client->cleanup_pipeline($pipeline);
```

### S3 Client Access

#### `s3([$s3_client])`

Gets or sets the S3 client.

**Parameters:**
- `$s3_client` (object, optional): Net::Amazon::S3 instance to set

**Returns:** Net::Amazon::S3 instance

**Example:**
```perl
my $s3 = $client->s3();
```

### Presigned URL Generation

#### `handle_generate_presigned_urls($bucket, $config)`

Generates presigned URLs for browser-based S3 uploads.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$config` (hashref, required): Configuration object

**Config Parameters:**
- `max_files` (integer, optional): Maximum number of files
- `min_files` (integer, optional): Minimum number of files (default: 0)
- `expires_in` (integer, optional): Expiration time in seconds (default: 3600)
- `content_types` (arrayref, optional): Allowed content types

**Content Type Structure:**
```perl
[
    {
        type => 'application/pdf',  # MIME type
        limit => 20                  # Size limit in MB (optional)
    },
    {
        type => 'image/jpeg',
        limit => 5
    }
]
```

**Returns:** Arrayref of presigned URL objects or output to STDOUT

**Throws:** Dies on validation error

**Example:**
```perl
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
```

## FileServerSdk::SequentialPipeline

Represents a pipeline that executes tasks sequentially.

### Constructor

#### `new(%args)`

Creates a new sequential pipeline.

**Parameters:** None

**Returns:** SequentialPipeline instance

**Example:**
```perl
my $pipeline = FileServerSdk::SequentialPipeline->new();
```

### Methods

#### `add_task_step($task)`

Adds a task to the pipeline.

**Parameters:**
- `$task` (object, required): Task with `to_json()` and `get_files()` methods

**Returns:** $self (for method chaining)

**Throws:** Dies if task doesn't have required methods

**Example:**
```perl
$pipeline->add_task_step($task1)->add_task_step($task2);
```

#### `add_parallel_pipeline_step($parallel_pipeline)`

Adds a parallel pipeline as a step.

**Parameters:**
- `$parallel_pipeline` (ParallelPipeline, required): Parallel pipeline instance

**Returns:** $self (for method chaining)

**Throws:** Dies if object doesn't have required methods

**Example:**
```perl
$pipeline->add_parallel_pipeline_step($parallel);
```

#### `get_steps()`

Gets all steps in the pipeline.

**Parameters:** None

**Returns:** List of step objects

**Example:**
```perl
my @steps = $pipeline->get_steps();
```

#### `get_files()`

Gets all files referenced in the pipeline.

**Parameters:** None

**Returns:** List of file paths

**Example:**
```perl
my @files = $pipeline->get_files();
```

#### `to_json()`

Converts the pipeline to JSON representation.

**Parameters:** None

**Returns:** Hashref (step index => step JSON)

**Example:**
```perl
my $json = $pipeline->to_json();
```

## FileServerSdk::ParallelPipeline

Represents a pipeline that executes multiple sequential pipelines in parallel.

### Constructor

#### `new(%args)`

Creates a new parallel pipeline.

**Parameters:** None

**Returns:** ParallelPipeline instance

**Example:**
```perl
my $pipeline = FileServerSdk::ParallelPipeline->new();
```

### Methods

#### `add_sequential_pipeline($seq_pipeline)`

Adds a sequential pipeline.

**Parameters:**
- `$seq_pipeline` (SequentialPipeline, required): Sequential pipeline instance

**Returns:** $self (for method chaining)

**Throws:** Dies if object doesn't have required methods

**Example:**
```perl
$parallel->add_sequential_pipeline($seq1)->add_sequential_pipeline($seq2);
```

#### `get_steps()`

Gets all sequential pipelines.

**Parameters:** None

**Returns:** List of SequentialPipeline objects

**Example:**
```perl
my @pipelines = $parallel->get_steps();
```

#### `get_files()`

Gets all files referenced in all pipelines.

**Parameters:** None

**Returns:** List of file paths

**Example:**
```perl
my @files = $parallel->get_files();
```

#### `to_json()`

Converts the pipeline to JSON representation.

**Parameters:** None

**Returns:** Arrayref of step JSONs

**Example:**
```perl
my $json = $parallel->to_json();
```

## FileServerSdk::Tasks::PdfMergerTask

Built-in task for merging PDF files.

### Constructor

#### `new(%args)`

Creates a new PDF merger task.

**Parameters:**
- `input_files` (arrayref, required): List of S3 file paths to merge
- `output_file` (string, required): S3 path for output file

**Returns:** PdfMergerTask instance

**Throws:** Dies if required parameters are missing or invalid

**Example:**
```perl
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['bucket/file1.pdf', 'bucket/file2.pdf'],
    output_file => 'bucket/merged.pdf'
);
```

### Methods

#### `input_files()`

Gets the list of input files.

**Parameters:** None

**Returns:** Arrayref of file paths

**Example:**
```perl
my $files = $task->input_files();
```

#### `output_file()`

Gets the output file path.

**Parameters:** None

**Returns:** File path (string)

**Example:**
```perl
my $output = $task->output_file();
```

#### `to_json()`

Converts the task to JSON representation.

**Parameters:** None

**Returns:** Hashref with task type and files

**Example:**
```perl
my $json = $task->to_json();
```

#### `get_files()`

Gets all files (input and output).

**Parameters:** None

**Returns:** List of file paths

**Example:**
```perl
my @files = $task->get_files();
```

## Custom Task Interface

When creating custom tasks, implement these methods:

```perl
package FileServerSdk::Tasks::CustomTask;

# Required constructor
sub new {
    my ($class, %args) = @_;
    # Validate arguments
    my $self = { %args };
    bless $self, $class;
    return $self;
}

# Required: JSON serialization
sub to_json {
    my ($self) = @_;
    return {
        type => 'task_type_name',
        inputFile => $self->{input_file},
        outputFile => $self->{output_file},
    };
}

# Required: File tracking
sub get_files {
    my ($self) = @_;
    return ($self->{output_file}, $self->{input_file});
}

1;
```

## Error Handling

All methods throw exceptions (die) on error. Handle using eval:

```perl
eval {
    $client->upload_file($bucket, $key, $content);
};

if ($@) {
    warn "Error: $@\n";
}
```

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `ACCESS_KEY_ID environment variable is required` | Missing env var | Set `ACCESS_KEY_ID` |
| `SECRET_ACCESS_KEY environment variable is required` | Missing env var | Set `SECRET_ACCESS_KEY` |
| `PIPELINE_SHARED_SECRET environment variable is required` | Missing env var | Set `PIPELINE_SHARED_SECRET` |
| `Failed to upload file` | S3 operation failed | Check credentials and bucket |
| `Failed to download file` | File not found or access denied | Check file path and permissions |
| `pipeline is required` | Missing pipeline parameter | Pass pipeline object |
| `webhook_url is required if callbacks are provided` | Incomplete webhook setup | Provide all 3 webhook parameters |
| `Number of files exceeds the maximum limit` | Too many files in presigned URL request | Reduce file count or increase `max_files` |
| `Content type is not allowed` | File type not in whitelist | Specify allowed `content_types` |
| `File size exceeds the limit` | File too large | Increase size limit or reject file |

