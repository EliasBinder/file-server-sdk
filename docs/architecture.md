# Architecture Overview

The File Server SDK is designed with a modular, layered architecture that separates concerns and enables flexible file processing workflows.

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│         Application Layer (Your Code)                   │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Pipeline Builders                        │  │
│  │  ┌────────────────┐    ┌─────────────────────┐  │  │
│  │  │SequentialPipe │    │ ParallelPipeline    │  │  │
│  │  └────────────────┘    └─────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Task Layer                             │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │     PdfMergerTask (extensible)             │  │  │
│  │  │     CustomTask                             │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                           │
├─────────────────────────────────────────────────────────┤
│               Client Layer (FileServerSdk::Client)      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Pipeline Execution                             │  │
│  │  - execute_pipeline()                           │  │
│  │  - handle_webhook()                             │  │
│  │  - cleanup_pipeline()                           │  │
│  └──────────────────────────────────────────────────┘  │
│                                                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │  File Operations                                │  │
│  │  - upload_file()                                │  │
│  │  - download_file()                              │  │
│  │  - delete_file()                                │  │
│  │  - get_metadata()                               │  │
│  │  - set_metadata()                               │  │
│  └──────────────────────────────────────────────────┘  │
│                                                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Presigned URL Generation                       │  │
│  │  - handle_generate_presigned_urls()             │  │
│  └──────────────────────────────────────────────────┘  │
│                                                           │
├─────────────────────────────────────────────────────────┤
│           Integration Layer (External Services)         │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐  ┌─────────────────────────────┐ │
│  │  S3 Storage      │  │  Pipeline Management Server │ │
│  │  (Net::Amazon::S3)  │  - /pipeline endpoint       │ │
│  └──────────────────┘  │  - /metadata endpoint       │ │
│                        └─────────────────────────────┘ │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Client (FileServerSdk::Client)

The main entry point and orchestrator for all SDK operations.

**Responsibilities:**
- Authentication and credential management
- S3 client initialization and management
- Pipeline execution and monitoring
- File operations (CRUD)
- Webhook management and callback handling
- Presigned URL generation for browser uploads

**Key Features:**
- Singleton pattern with lazy initialization
- Automatic credential validation
- JSON serialization/deserialization
- Error handling and validation

### 2. Pipeline Layer

#### SequentialPipeline

Represents a series of tasks that execute one after another.

**Structure:**
```
Task 1 → Task 2 → Task 3 → Task 4
```

**Use Cases:**
- Dependent operations
- Multi-stage processing
- Tasks requiring output from previous steps

#### ParallelPipeline

Represents multiple independent sequential pipelines executing concurrently.

**Structure:**
```
├─ Seq Pipeline 1 (Task 1 → Task 2)
├─ Seq Pipeline 2 (Task 3 → Task 4)
└─ Seq Pipeline 3 (Task 5)
```

**Use Cases:**
- Independent batch operations
- Multi-processing workflows
- Leveraging system concurrency

#### Nested Pipelines

Pipelines can be nested to create complex workflows:

```
Sequential Pipeline
├─ Task 1
├─ Parallel Pipeline
│  ├─ Sequential Pipeline (Task 2 → Task 3)
│  └─ Sequential Pipeline (Task 4)
└─ Task 5
```

### 3. Task Layer

Tasks represent individual processing units. They:
- Define input and output files
- Specify processing parameters
- Provide JSON serialization for transmission
- Track file resources for cleanup

**Custom Task Interface:**

To create a custom task, implement:
```perl
package FileServerSdk::Tasks::MyTask;

sub new { ... }
sub to_json { ... }
sub get_files { ... }
```

### 4. Authentication and Security

**Credential Management:**
- All credentials passed via environment variables
- No credentials hardcoded or logged
- Support for S3 authentication (AWS Signature V4)
- Webhook signature verification via shared secret

**Supported Authentication Methods:**
- S3: AWS Signature V4 with Access Key/Secret Key
- Pipeline Server: Shared Secret validation

### 5. File Storage Integration

**S3 Integration:**
- Uses Net::Amazon::S3 for S3 operations
- Supports S3-compatible storage
- Configurable host and region
- Automatic retry on failure

**Supported Operations:**
- Upload/Download files
- Delete files
- Get/Set file metadata
- Generate presigned URLs for browser uploads

### 6. Pipeline Server Communication

**Endpoints:**
- Pipeline Execution: `PUT /pipeline`
- Metadata Operations: `PATCH /metadata`, `GET /metadata`
- Webhook Callbacks: HTTP POST to configured URL

**Request Flow:**
```
1. Client builds pipeline JSON
2. Client sends to pipeline server with shared secret
3. Server processes and returns pipeline ID
4. Server executes pipeline asynchronously
5. Server calls webhook URL on completion
6. Client handles webhook and executes callback
```

## Data Flow

### Execution with Webhook

```
┌────────────┐
│ Application│
└──────┬─────┘
       │
       ├─ Build pipeline
       ├─ Register callbacks
       │
       ▼
┌──────────────────────┐
│  FileServerSdk::Client  │
└──────┬───────────────┘
       │
       ├─ Serialize to JSON
       ├─ Validate inputs
       │
       ▼
┌──────────────────────┐
│ Pipeline Server      │
└──────┬───────────────┘
       │
       ├─ Store callbacks
       ├─ Execute pipeline
       ├─ Process files
       │
       └─ HTTP POST → Webhook URL
         └─ Callback to application
```

### File Processing Pipeline

```
Input Files (S3)
       │
       ▼
┌──────────────┐
│ Task 1       │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Task 2       │
└──────┬───────┘
       │
       ▼
Output File (S3)
```

## Configuration

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ACCESS_KEY_ID` | Required | S3 access key |
| `SECRET_ACCESS_KEY` | Required | S3 secret key |
| `PIPELINE_SHARED_SECRET` | Required | Server authentication |
| `S3_HOST` | s3.primuss.de | S3 endpoint |
| `PIPELINE_ENDPOINT` | https://pipeline-mgm.primuss.de/pipeline | Pipeline server URL |
| `METADATA_ENDPOINT` | https://pipeline-mgm.primuss.de/metadata | Metadata server URL |

## Design Patterns Used

### 1. Builder Pattern
Pipeline construction uses method chaining:
```perl
$pipeline->add_task_step($task1)->add_task_step($task2);
```

### 2. Strategy Pattern
Different task types implement a common interface for processing.

### 3. Observer Pattern
Webhooks and callbacks implement event notification.

### 4. Facade Pattern
The Client class provides a simplified interface to complex subsystems.

### 5. Factory Pattern
Pipeline and task creation through constructors.

## Error Handling

The SDK uses exceptions (die) for error conditions:

```perl
eval {
    $client->execute_pipeline($pipeline);
};
if ($@) {
    warn "Pipeline execution failed: $@\n";
}
```

**Error Sources:**
- Missing environment variables
- Invalid input parameters
- Network failures
- S3 operation failures
- Server errors

## Thread Safety

The current implementation is **not thread-safe**. The Client stores callbacks in a hash:

```perl
$self->{callbacks}->{$pipelineId} = { ... };
```

For multi-threaded applications, synchronize access to the callback hash or use separate client instances per thread.

## Performance Considerations

1. **Pipeline Size**: Large pipelines with many tasks may take longer to serialize
2. **File Operations**: S3 operations may be I/O bound; consider using streams for large files
3. **Webhook Latency**: The application server should respond quickly to webhooks
4. **Concurrent Pipelines**: Multiple parallel pipelines can be executed concurrently

## Extensibility

The SDK is designed to be extended:

1. **Custom Tasks**: Implement the task interface
2. **Custom Pipelines**: Inherit from SequentialPipeline
3. **Custom Client Methods**: Extend the Client class
4. **Alternative Storage**: Swap the S3 client for another storage backend

See [Tasks Documentation](tasks.md) for details on creating custom tasks.
