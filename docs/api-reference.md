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

#### `upload_file($bucket, $key, $content, $content_type)`

Uploads content to S3.

**Parameters:**
- `$bucket` (string, required): S3 bucket name
- `$key` (string, required): S3 object key (path)
- `$content` (string, required): File content to upload
- `$content_type` (string, required): MIME type (e.g., 'application/pdf')

**Returns:** 1 on success

**Throws:** Dies on error

**Example:**
```perl
$client->upload_file('my-bucket', 'documents/file.pdf', $content, 'application/pdf');
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

#### `execute_pipeline($pipeline, [$pipeline_id, $webhook_url])`

Executes a pipeline. For webhook scenarios, you should pre-generate and pass a pipeline ID.

**Parameters:**
- `$pipeline` (object, required): SequentialPipeline or ParallelPipeline instance
- `$pipeline_id` (string, optional): Unique pipeline ID. If omitted, one is generated automatically.
- `$webhook_url` (string, optional): URL for webhook callbacks

**Returns:** Pipeline ID (string)

**Throws:** Dies on error

**Usage Patterns:**

```perl
# Pattern 1: Simple execution without webhooks (auto-generated ID)
my $pipeline_id = $client->execute_pipeline($pipeline);

# Pattern 2: With pre-generated ID (for database tracking)
my $pipeline_id = $client->gen_uuid();
my $result = $client->execute_pipeline(
    $pipeline_id,
    $pipeline,
    'https://your-server.com/webhook?action=webhook'
);

# Pattern 3: Pre-allocate resources before execution
my $pipeline_id = $client->gen_uuid();
store_in_database($pipeline_id, 'pending');  # Reserve resources
my $result = $client->execute_pipeline(
    $pipeline_id,
    $pipeline,
    'https://your-server.com/webhook?action=webhook'
);
```

#### `handle_webhook($on_success, $on_error)`

Processes incoming webhook requests from the pipeline server.

**Parameters:**
- `$on_success` (code ref, optional): Callback for successful pipeline completion
- `$on_error` (code ref, optional): Callback for pipeline failure

**Callback Signatures:**
- Success: `sub { my ($pipeline_id) = @_; }` - Receives pipeline ID
- Error: `sub { my ($pipeline_id, $error) = @_; }` - Receives pipeline ID and error message

**CGI Parameters Expected (automatically validated):**
- `secret`: Shared secret (validated against `PIPELINE_SHARED_SECRET`)
- `pipelineId`: Pipeline ID from server
- `status`: Pipeline status ('completed', 'failed', etc.)
- `error`: Error message (only if status indicates failure)

**Returns:** 1 on success, 0 on validation failure

**Example:**
```perl
if ($action eq 'webhook') {
    $client->handle_webhook(
        sub {
            my ($pipeline_id) = @_;
            update_database($pipeline_id, 'completed');
        },
        sub {
            my ($pipeline_id, $error) = @_;
            update_database($pipeline_id, 'failed', $error);
        }
    );
}
```

#### `cleanup_pipeline($pipeline)`

Deletes all files associated with a pipeline.

**Parameters:**
- `$pipeline` (object, required): SequentialPipeline or ParallelPipeline instance

**Returns:** 1 on success

**Throws:** Warnings on individual file deletion failures

**Example:**
```perl
$client->cleanup_pipeline($pipeline);
```

#### `gen_uuid()`

Generates a new unique UUID suitable for use as a pipeline ID.

**Parameters:** None

**Returns:** String containing a UUID (format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx)

**Example:**
```perl
my $pipeline_id = $client->gen_uuid();
print "Generated ID: $pipeline_id\n";
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
    $client->upload_file($bucket, $key, $content, 'application/pdf');
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
| `Number of files exceeds the maximum limit` | Too many files in presigned URL request | Reduce file count or increase `max_files` |
| `Content type is not allowed` | File type not in whitelist | Specify allowed `content_types` |
| `File size exceeds the limit` | File too large | Increase size limit or reject file |

## Pipeline ID Management

The SDK supports explicit pipeline ID management for better tracking and resource allocation:

### Why Use Pre-Generated IDs?

1. **Database Tracking**: Store pipeline IDs before execution begins
2. **Resource Allocation**: Pre-allocate storage or processing resources
3. **User Session Linking**: Associate pipelines with user sessions
4. **Audit Trail**: Create a complete history from submission to completion

### Best Practice Pattern

```perl
# Step 1: Generate ID
my $pipeline_id = $client->gen_uuid();

# Step 2: Create database record (pre-allocate resources)
my $sth = $dbh->prepare(q{
    INSERT INTO pipeline_jobs (job_id, user_id, status, created_at)
    VALUES (?, ?, 'pending', NOW())
});
$sth->execute($pipeline_id, $user_id);

# Step 3: Execute pipeline with known ID
my $result = $client->execute_pipeline(
    $pipeline_id,
    $pipeline,
    'https://your-server.com/webhook?action=webhook'
);

# Step 4: Webhook callback updates the same record
# The pipeline_id in the callback matches the ID you created
```
