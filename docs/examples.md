# Examples and Troubleshooting

Practical examples and solutions to common issues.

## Real-World Examples

### Example 1: Document Merge Application

A web application where users upload multiple PDFs and get a merged document back.

```perl
#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard -utf8/;
use JSON;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $action = param('action');
my $client = FileServerSdk::Client->new();
my $json = JSON->new->allow_nonref;

if ($action eq 'upload') {
    # Handle presigned URL generation
    eval {
        my $urls = $client->handle_generate_presigned_urls(
            'document-processor',
            {
                max_files => 10,
                min_files => 2,
                expires_in => 3600,
                content_types => [
                    { type => 'application/pdf', limit => 50 }
                ]
            }
        );
    };
    
    if ($@) {
        print header(-status => '400 Bad Request', 'application/json');
        print $json->encode({ error => $@ });
    }
} 
elsif ($action eq 'merge') {
    # Create merge pipeline
    my @files = split(',', param('files'));
    
    eval {
        my $task = FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => \@files,
            output_file => 'document-processor/merged/' . time() . '.pdf'
        );
        
        my $pipeline = FileServerSdk::SequentialPipeline->new()
            ->add_task_step($task);
        
        my $pipeline_id = $client->execute_pipeline(
            $pipeline,
            'https://myapp.com/api/merge?action=webhook',
            sub {
                # Success
                update_job_status($pipeline_id, 'completed');
                notify_user($pipeline_id, 'Your documents have been merged!');
            },
            sub {
                my ($error) = @_;
                # Error
                update_job_status($pipeline_id, 'failed', $error);
                notify_user($pipeline_id, "Merge failed: $error");
            }
        );
        
        print header('application/json');
        print $json->encode({
            pipeline_id => $pipeline_id,
            status => 'processing'
        });
    };
    
    if ($@) {
        print header(-status => '500 Internal Server Error', 'application/json');
        print $json->encode({ error => $@ });
    }
}
elsif ($action eq 'webhook') {
    # Handle webhook callback
    $client->handle_webhook();
}

sub update_job_status {
    my ($pipeline_id, $status, $error) = @_;
    # Update database with job status
}

sub notify_user {
    my ($pipeline_id, $message) = @_;
    # Send email or push notification
}
```

### Example 2: Batch Processing System

Process multiple document sets in parallel.

```perl
#!/usr/bin/perl
use strict;
use warnings;
use FileServerSdk::Client;
use FileServerSdk::ParallelPipeline;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

# Define multiple independent jobs
my @jobs = (
    {
        name => 'Department A',
        files => ['batch/dept-a/file1.pdf', 'batch/dept-a/file2.pdf'],
        output => 'batch/dept-a/merged.pdf'
    },
    {
        name => 'Department B',
        files => ['batch/dept-b/file1.pdf', 'batch/dept-b/file2.pdf'],
        output => 'batch/dept-b/merged.pdf'
    },
    {
        name => 'Department C',
        files => ['batch/dept-c/file1.pdf', 'batch/dept-c/file2.pdf'],
        output => 'batch/dept-c/merged.pdf'
    },
);

# Create parallel pipeline with independent jobs
my $parallel = FileServerSdk::ParallelPipeline->new();

foreach my $job (@jobs) {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => $job->{files},
        output_file => $job->{output}
    );
    
    my $seq = FileServerSdk::SequentialPipeline->new()
        ->add_task_step($task);
    
    $parallel->add_sequential_pipeline($seq);
}

# Execute all jobs in parallel
my $pipeline_id = $client->execute_pipeline(
    $parallel,
    'https://myapp.com/api/batch?action=webhook',
    sub {
        print "All batch jobs completed successfully!\n";
        log_completion('batch_success', $pipeline_id);
    },
    sub {
        my ($error) = @_;
        print "Batch processing failed: $error\n";
        log_completion('batch_error', $pipeline_id, $error);
    }
);

print "Batch processing started with ID: $pipeline_id\n";
```

### Example 3: File Organization System

Upload files with automatic organization and metadata.

```perl
#!/usr/bin/perl
use strict;
use warnings;
use FileServerSdk::Client;
use File::Temp qw(tempfile);
use Digest::SHA qw(sha256_hex);

my $client = FileServerSdk::Client->new();
my $bucket = 'file-storage';

sub organize_file {
    my ($file_path, $category, $user_id) = @_;
    
    # Read file
    open(my $fh, '<', $file_path) or die "Cannot read $file_path: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    # Calculate file hash for deduplication
    my $hash = sha256_hex($content);
    
    # Organize by date and category
    my @date = localtime();
    my $year = $date[5] + 1900;
    my $month = sprintf('%02d', $date[4] + 1);
    my $day = sprintf('%02d', $date[3]);
    
    my $filename = (split('/', $file_path))[-1];
    my $s3_key = "$category/$year/$month/$day/$filename";
    
    # Upload to S3
    eval {
        $client->upload_file($bucket, $s3_key, $content);
        
        # Set metadata
        my $metadata = {
            original_file => $filename,
            category => $category,
            user_id => $user_id,
            upload_date => time(),
            file_hash => $hash,
        };
        
        $client->set_metadata($bucket, $s3_key, $metadata);
        
        return {
            success => 1,
            s3_key => $s3_key,
            hash => $hash
        };
    };
    
    if ($@) {
        return {
            success => 0,
            error => $@
        };
    }
}

# Usage
my $result = organize_file('/tmp/document.pdf', 'reports', 'user123');

if ($result->{success}) {
    print "File organized: $result->{s3_key}\n";
} else {
    print "Upload failed: $result->{error}\n";
}
```

## Troubleshooting Guide

### Environment Setup Issues

#### Problem: "ACCESS_KEY_ID environment variable is required"

```perl
# Wrong
use FileServerSdk::Client;
my $client = FileServerSdk::Client->new();  # Dies here

# Right
$ENV{ACCESS_KEY_ID} = 'your_key';
$ENV{SECRET_ACCESS_KEY} = 'your_secret';
$ENV{PIPELINE_SHARED_SECRET} = 'your_secret';

use FileServerSdk::Client;
my $client = FileServerSdk::Client->new();  # Works
```

#### Solution: Set all three required environment variables

```bash
export ACCESS_KEY_ID="your_access_key"
export SECRET_ACCESS_KEY="your_secret_key"
export PIPELINE_SHARED_SECRET="your_pipeline_secret"

perl your_script.pl
```

### Connection Issues

#### Problem: Connection timeout to S3

```
Failed to upload file: Connection timeout
```

**Diagnostic Steps:**

```bash
# Test S3 connectivity
curl -I https://s3.primuss.de

# Check DNS resolution
nslookup s3.primuss.de

# Check firewall/proxy
ping s3.primuss.de
```

**Solutions:**

1. Check network connectivity
2. Verify S3_HOST environment variable
3. Check firewall rules
4. Check proxy settings if behind corporate proxy

```perl
# Verify S3 host configuration
print "S3 Host: " . ($ENV{S3_HOST} || 's3.primuss.de') . "\n";
```

### File Operation Issues

#### Problem: "Failed to download file: 404 Not Found"

**Cause:** File doesn't exist at the specified path

**Solution:**

```perl
# Wrong - incorrect path format
my $content = $client->download_file('my-bucket', 'file.pdf');

# Right - correct path format
my $content = $client->download_file('my-bucket', 'path/to/file.pdf');

# Debug: List what you think is in S3
# (Note: SDK doesn't provide list functionality, track file paths yourself)
```

#### Problem: "Failed to upload file: 403 Forbidden"

**Cause:** Insufficient permissions

**Solutions:**

1. Verify AWS credentials have s3:PutObject permission
2. Check bucket policy
3. Verify bucket name is correct

```perl
# Test with a simple upload
eval {
    $client->upload_file('my-bucket', 'test.txt', 'test content');
};

if ($@) {
    print "Upload error: $@\n";
    # Check credentials and permissions
}
```

### Pipeline Execution Issues

#### Problem: Pipeline not executing

**Diagnostic:**

```perl
eval {
    my $pipeline_id = $client->execute_pipeline($pipeline);
    print "Pipeline ID: $pipeline_id\n";
};

if ($@) {
    print "Error: $@\n";
}
```

**Common Causes:**

1. **Webhook URL unreachable**
   ```bash
   # Test webhook URL
   curl -X POST https://your-app.com/webhook?action=webhook
   ```

2. **Input files don't exist**
   ```perl
   # Verify files exist before executing
   foreach my $file ($pipeline->get_files()) {
       print "Checking: $file\n";
   }
   ```

3. **Invalid pipeline structure**
   ```perl
   # Validate pipeline
   my @steps = $pipeline->get_steps();
   print "Pipeline has " . scalar(@steps) . " steps\n";
   ```

#### Problem: Webhook callback not firing

**Diagnostic:**

```perl
# 1. Verify webhook URL is correct
print "Webhook URL: $webhook_url\n";

# 2. Check if server can reach your webhook
curl -X POST "$webhook_url"

# 3. Verify shared secret matches
print "Secret: " . $ENV{PIPELINE_SHARED_SECRET} . "\n";

# 4. Enable webhook logging
my $on_success = sub {
    warn "Success callback called at " . scalar(localtime()) . "\n";
};
```

**Solutions:**

1. Ensure webhook URL is publicly accessible
2. Use HTTPS in production
3. Verify firewall allows incoming connections
4. Check server logs for webhook attempts
5. Use ngrok for local testing

```perl
# Local testing with ngrok
# In terminal: ngrok http 3000
# In code: $webhook_url = 'https://abc123.ngrok.io/webhook?action=webhook'
```

### Presigned URL Issues

#### Problem: "Number of files exceeds the maximum limit"

```perl
# Wrong
my $urls = $client->handle_generate_presigned_urls(
    'bucket',
    { max_files => 5 }
);
# But user requests 10 files

# Right
my $urls = $client->handle_generate_presigned_urls(
    'bucket',
    { max_files => 10 }
);
```

#### Problem: "Content type is not allowed"

```perl
# Wrong - PDF requested but only JPEG allowed
$urls = $client->handle_generate_presigned_urls(
    'bucket',
    {
        content_types => [
            { type => 'image/jpeg', limit => 5 }
        ]
    }
);

# Right - specify all allowed types
$urls = $client->handle_generate_presigned_urls(
    'bucket',
    {
        content_types => [
            { type => 'application/pdf', limit => 20 },
            { type => 'image/jpeg', limit => 5 }
        ]
    }
);
```

#### Problem: "File size exceeds the limit"

```perl
# Wrong - 50MB file with 20MB limit
{ type => 'application/pdf', limit => 20 }

# Right - increase limit or reject large files
{ type => 'application/pdf', limit => 100 }
```

### Metadata Issues

#### Problem: Metadata not found

```perl
eval {
    my $metadata = $client->get_metadata('bucket', 'file.pdf');
};

if ($@) {
    if ($@ =~ /404/) {
        print "Metadata doesn't exist - create it first\n";
        $client->set_metadata('bucket', 'file.pdf', {});
    } else {
        die "Error: $@\n";
    }
}
```

#### Problem: Metadata not persisting

```perl
# Make sure to set metadata AFTER file upload
$client->upload_file($bucket, $key, $content);

# Then set metadata
$client->set_metadata($bucket, $key, {
    author => 'John',
    date => time()
});
```

### Performance Issues

#### Problem: Slow uploads for large files

**Solutions:**

1. Upload in chunks
2. Use faster network
3. Verify credentials don't require MFA
4. Check for network congestion

```perl
# Monitor upload progress
my $chunk_size = 1024 * 1024;  # 1MB chunks
open(my $fh, '<', $file) or die $!;

my $total = 0;
while (read($fh, my $chunk, $chunk_size)) {
    $total += length($chunk);
    printf "Uploaded %d bytes\n", $total;
}
close($fh);
```

#### Problem: Pipeline execution is slow

**Solutions:**

1. Use parallel pipelines for independent tasks
2. Reduce pipeline complexity
3. Check server logs for bottlenecks
4. Monitor resource usage

```perl
# Use parallel for independent operations
my $parallel = FileServerSdk::ParallelPipeline->new();
$parallel->add_sequential_pipeline($seq1);
$parallel->add_sequential_pipeline($seq2);
$parallel->add_sequential_pipeline($seq3);

# All three will execute concurrently
```

## Debugging Tips

### Enable Verbose Logging

```perl
use strict;
use warnings;

# Enable all warnings
$SIG{__WARN__} = sub {
    my ($warning) = @_;
    print STDERR "[WARNING] $warning\n";
    warn $warning;
};

# Log all API calls
my $client = FileServerSdk::Client->new();

# Wrap methods to log calls
my $original_upload = $client->can('upload_file');
*FileServerSdk::Client::upload_file = sub {
    my ($self, $bucket, $key, $content) = @_;
    warn "Uploading to $bucket/$key (" . length($content) . " bytes)\n";
    $original_upload->($self, $bucket, $key, $content);
};
```

### Test Individual Components

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Test 1: Client creation
print "Test 1: Client creation\n";
eval {
    use FileServerSdk::Client;
    my $client = FileServerSdk::Client->new();
    print "  OK\n";
};
print "  ERROR: $@\n" if $@;

# Test 2: File operations
print "Test 2: File operations\n";
eval {
    $client->upload_file('test-bucket', 'test.txt', 'test');
    my $content = $client->download_file('test-bucket', 'test.txt');
    print "  OK\n";
};
print "  ERROR: $@\n" if $@;

# Test 3: Pipeline creation
print "Test 3: Pipeline creation\n";
eval {
    use FileServerSdk::SequentialPipeline;
    my $pipeline = FileServerSdk::SequentialPipeline->new();
    print "  OK\n";
};
print "  ERROR: $@\n" if $@;
```

### Check Configuration

```perl
#!/usr/bin/perl
use strict;
use warnings;

print "=== Configuration Check ===\n";

# Check environment variables
foreach my $var (qw(ACCESS_KEY_ID SECRET_ACCESS_KEY PIPELINE_SHARED_SECRET)) {
    my $value = $ENV{$var};
    my $status = $value ? "SET" : "NOT SET";
    print "$var: $status\n";
}

# Check optional variables
foreach my $var (qw(S3_HOST PIPELINE_ENDPOINT METADATA_ENDPOINT)) {
    my $value = $ENV{$var};
    printf "%s: %s\n", $var, ($value || "(default)");
}

print "\nRequired Perl modules:\n";
my @modules = qw(
    FileServerSdk::Client
    Net::Amazon::S3
    HTTP::Tiny
    JSON
);

foreach my $module (@modules) {
    eval "use $module";
    my $status = $@ ? "NOT INSTALLED" : "OK";
    print "  $module: $status\n";
}
```

