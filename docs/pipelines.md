# Pipelines Guide

Pipelines are the core mechanism for building and executing complex file processing workflows. This guide explains how to use and create pipelines.

## Pipeline Types

### SequentialPipeline

A sequential pipeline executes tasks one after another in order. Each task starts only after the previous one completes.

**When to use:**
- Dependent operations where later tasks need output from earlier tasks
- Multi-stage processing workflows
- Tasks that must execute in a specific order

**Example:**
```perl
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2)
    ->add_task_step($task3);
```

**Execution Flow:**
```
Task 1 → Task 2 → Task 3
(wait)  (wait)  (done)
```

### ParallelPipeline

A parallel pipeline executes multiple independent sequential pipelines concurrently.

**When to use:**
- Independent batch operations
- Multi-branch workflows
- Operations that don't depend on each other
- Leveraging system concurrency

**Example:**
```perl
use FileServerSdk::ParallelPipeline;
use FileServerSdk::SequentialPipeline;

my $seq1 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2);

my $seq2 = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task3);

my $parallel = FileServerSdk::ParallelPipeline->new()
    ->add_sequential_pipeline($seq1)
    ->add_sequential_pipeline($seq2);
```

**Execution Flow:**
```
├─ Task 1 → Task 2  ┐
├─ Task 3           ├─ Execute in parallel
└─────────────────┘
```

## Nested Pipelines

You can nest pipelines to create complex workflows. A sequential pipeline can contain parallel pipelines as steps, and vice versa.

**Example: Sequential with Parallel Steps**

```perl
my $parallel = FileServerSdk::ParallelPipeline->new()
    ->add_sequential_pipeline($seq1)
    ->add_sequential_pipeline($seq2);

my $main_pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($initial_task)
    ->add_parallel_pipeline_step($parallel)
    ->add_task_step($final_task);
```

**Execution Flow:**
```
Initial Task
    ↓
├─ Parallel Pipeline 1 ┐
├─ Parallel Pipeline 2 ├─ (parallel)
├─ Parallel Pipeline 3 ┘
    ↓
Final Task
```

## Building Pipelines

### Method Chaining

Pipelines support method chaining for fluent API usage:

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task1)
    ->add_task_step($task2)
    ->add_task_step($task3);
```

### Step-by-Step Construction

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new();
$pipeline->add_task_step($task1);
$pipeline->add_task_step($task2);
$pipeline->add_task_step($task3);
```

### Dynamic Pipeline Building

```perl
my $pipeline = FileServerSdk::SequentialPipeline->new();

foreach my $task (@tasks) {
    $pipeline->add_task_step($task);
}
```

## Pipeline Execution

### Simple Execution (No Callbacks)

```perl
my $client = FileServerSdk::Client->new();
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

my $pipeline_id = $client->execute_pipeline($pipeline);
print "Pipeline ID: $pipeline_id\n";
```

### With Webhook and Callbacks

```perl
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-server.com/webhook?action=webhook',
    sub {
        # Success callback
        print "Pipeline completed!\n";
    },
    sub {
        my ($error) = @_;
        # Error callback
        print "Pipeline failed: $error\n";
    }
);
```

### With Pipeline Metadata

Metadata can be attached to a pipeline execution. This metadata will be returned in the webhook callbacks for both successful and failed pipeline completions, allowing you to correlate pipeline executions with your application state:

```perl
my $metadata = {
    user_id => 12345,
    job_type => 'document_processing',
    request_id => 'req-abc123',
    custom_field => 'custom_value'
};

my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-server.com/webhook?action=webhook',
    $metadata
);
```

You can also combine a pipeline ID with metadata:

```perl
my $pipeline_id = $client->execute_pipeline(
    'my-pipeline-123',      # Explicit pipeline ID
    $pipeline,
    'https://your-server.com/webhook?action=webhook',
    $metadata
);
```

### Error Handling

```perl
eval {
    my $pipeline_id = $client->execute_pipeline($pipeline);
};
if ($@) {
    die "Failed to execute pipeline: $@\n";
}
```

### Method Signature

The `execute_pipeline` method supports the following signatures:

```perl
# Without webhook or metadata
$client->execute_pipeline($pipeline);

# With pipeline ID
$client->execute_pipeline($pipeline_id, $pipeline);

# With webhook URL
$client->execute_pipeline($pipeline, $webhook_url);

# With pipeline ID and webhook URL
$client->execute_pipeline($pipeline_id, $pipeline, $webhook_url);

# With metadata (attached to pipeline)
$client->execute_pipeline($pipeline, $webhook_url, $metadata);

# With pipeline ID and metadata
$client->execute_pipeline($pipeline_id, $pipeline, $webhook_url, $metadata);
```

The `$metadata` parameter should be a hash reference containing any application-specific data you want to associate with the pipeline execution.

## Advanced Examples

### Document Processing Pipeline

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

# Stage 1: Merge documents
my $merge_task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => [
        'docs/cover.pdf',
        'docs/content.pdf',
        'docs/appendix.pdf'
    ],
    output_file => 'docs/merged.pdf'
);

# Build pipeline
my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($merge_task);

# Execute
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-server.com/webhook',
    sub { print "Document merged successfully\n"; },
    sub { my ($e) = @_; print "Merge failed: $e\n"; }
);
```

### Batch Processing Pipeline

```perl
use FileServerSdk::Client;
use FileServerSdk::ParallelPipeline;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();
my $parallel = FileServerSdk::ParallelPipeline->new();

# Create multiple independent merge operations
for my $i (1..5) {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [
            "batch$i/file1.pdf",
            "batch$i/file2.pdf"
        ],
        output_file => "batch$i/merged.pdf"
    );
    
    my $seq = FileServerSdk::SequentialPipeline->new()
        ->add_task_step($task);
    
    $parallel->add_sequential_pipeline($seq);
}

# Execute all batches in parallel
my $pipeline_id = $client->execute_pipeline(
    $parallel,
    'https://your-server.com/webhook',
    sub { print "All batches completed\n"; },
    sub { my ($e) = @_; print "Batch processing failed: $e\n"; }
);
```

### Complex Multi-Stage Pipeline

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::ParallelPipeline;

my $client = FileServerSdk::Client->new();

# Stage 1: Data preparation (sequential)
my $prep_pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($validate_task)
    ->add_task_step($normalize_task);

# Stage 2: Parallel processing
my $processing = FileServerSdk::ParallelPipeline->new()
    ->add_sequential_pipeline($process1)
    ->add_sequential_pipeline($process2)
    ->add_sequential_pipeline($process3);

# Stage 3: Final aggregation (sequential)
my $final_pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($prep_pipeline)
    ->add_parallel_pipeline_step($processing)
    ->add_task_step($aggregate_task)
    ->add_task_step($report_task);

# Execute the entire workflow
my $pipeline_id = $client->execute_pipeline(
    $final_pipeline,
    'https://your-server.com/webhook',
    sub { print "Full pipeline completed\n"; },
    sub { my ($e) = @_; print "Pipeline failed: $e\n"; }
);
```

## Pipeline Inspection

### Get Pipeline Steps

```perl
my @steps = $pipeline->get_steps();
print "Pipeline has " . scalar(@steps) . " steps\n";
```

### Get All Files in Pipeline

```perl
my @files = $pipeline->get_files();
foreach my $file (@files) {
    print "File: $file\n";
}
```

### JSON Representation

```perl
my $json = $pipeline->to_json();
print "Pipeline JSON: " . JSON->new->encode($json) . "\n";
```

## Best Practices

### 1. Clear Pipeline Structure

Make pipelines easy to understand:

```perl
# Good - clear naming
my $validate_pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($validate_input);

my $process_pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($transform_data);

# Instead of
my $p1 = FileServerSdk::SequentialPipeline->new();
$p1->add_task_step($t1);
```

### 2. Reusable Pipeline Modules

```perl
package MyApp::Pipelines;

sub create_merge_pipeline {
    my ($input_files, $output_file) = @_;
    
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => $input_files,
        output_file => $output_file
    );
    
    return FileServerSdk::SequentialPipeline->new()
        ->add_task_step($task);
}

1;
```

### 3. Error Handling in Callbacks

```perl
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    $webhook_url,
    sub {
        eval {
            # Handle success
            process_results();
        };
        if ($@) {
            warn "Error in success callback: $@\n";
        }
    },
    sub {
        my ($error) = @_;
        eval {
            # Handle error
            log_error($error);
            notify_admin($error);
        };
        if ($@) {
            warn "Error in error callback: $@\n";
        }
    }
);
```

### 4. File Cleanup

```perl
# Don't forget to cleanup files after pipeline execution
my $pipeline_id = $client->execute_pipeline($pipeline);

# In webhook handler or later
$client->cleanup_pipeline($pipeline);
```

### 5. Validation Before Execution

```perl
# Validate inputs exist before execution
foreach my $file ($pipeline->get_files()) {
    die "Required file not found: $file" 
        unless file_exists($file);
}

my $pipeline_id = $client->execute_pipeline($pipeline);
```

## Performance Tips

1. **Use Parallel Pipelines for Independent Tasks**: Leverage concurrency
2. **Minimize File Dependencies**: Keep sequential steps to minimum
3. **Batch Operations**: Group related operations for efficiency
4. **Monitor Pipeline Execution**: Use webhooks to track progress
5. **Clean Up Resources**: Delete unnecessary files promptly

## Troubleshooting

### Pipeline Not Executing

- Verify all environment variables are set
- Check that webhook URL is reachable
- Ensure input files exist in S3
- Check server logs for error details

### Callback Not Being Called

- Verify webhook URL matches exactly in both execute call and webhook handler
- Check that pipeline server can reach your webhook URL
- Verify secret parameter matches in webhook handler

### File Not Found Errors

- Ensure files are in format: `bucket/key`
- Verify files exist in S3 before executing pipeline
- Check file permissions and access keys
