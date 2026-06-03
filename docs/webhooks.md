# Webhooks and Callbacks Guide

Webhooks allow your application to receive real-time notifications when pipelines complete or fail. This guide explains how to implement and handle webhooks with pipeline ID tracking.

## Overview of the Webhook Flow

The webhook system now supports explicit pipeline ID management:

1. Your application generates a unique pipeline ID using `gen_uuid()`
2. Optionally: Store a placeholder entry in your database with the pipeline ID
3. The client sends the pipeline to the server with the pipeline ID and webhook URL
4. The pipeline server executes the pipeline asynchronously
5. Upon completion (success or failure), the server makes an HTTP POST request to your webhook URL
6. Your application's webhook handler receives the pipeline ID in the callback

This workflow allows you to:
- Track pipeline execution in your database
- Link pipelines to user sessions or business entities
- Pre-allocate storage or resources before execution
- Update records with results when the webhook fires

## Setting Up Webhooks

### Basic Webhook Execution with ID Management

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['docs/file1.pdf', 'docs/file2.pdf'],
    output_file => 'docs/merged.pdf'
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

# Step 1: Generate a unique pipeline ID
my $pipeline_id = $client->gen_uuid();

# Step 2: Optionally create a placeholder in your database
eval {
    store_pipeline_record({
        pipeline_id => $pipeline_id,
        status => 'pending',
        created_at => time(),
    });
};

if ($@) {
    warn "Failed to create pipeline record: $@\n";
}

# Step 3: Execute with webhook (ID is now known to your application)
my $result = $client->execute_pipeline(
    $pipeline_id,
    $pipeline,
    'https://your-app.com/api/webhook?action=webhook'
);

print "Pipeline ID: $result\n";

sub store_pipeline_record {
    my ($record) = @_;
    # Store in your database
    # e.g., INSERT INTO pipelines (pipeline_id, status, created_at) VALUES (...)
}
```

### Simple CGI Webhook Handler

```perl
#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard -utf8/;
use FileServerSdk::Client;
use JSON;

my $action = param('action');
my $client = FileServerSdk::Client->new();

if ($action eq 'webhook') {
    # Handle the webhook callback
    $client->handle_webhook(
        sub {
            my ($pipeline_id, $metadata) = @_;
            # Success callback
            # $metadata is a hash reference with any data submitted during execute_pipeline
            print STDERR "Pipeline $pipeline_id completed successfully\n";
            if (defined $metadata) {
                print STDERR "Metadata: " . JSON->new->encode($metadata) . "\n";
            }
            update_pipeline_record($pipeline_id, 'completed', $metadata);
        },
        sub {
            my ($pipeline_id, $error, $metadata) = @_;
            # Error callback
            # $metadata is available even on failure
            print STDERR "Pipeline $pipeline_id failed: $error\n";
            if (defined $metadata) {
                print STDERR "Metadata: " . JSON->new->encode($metadata) . "\n";
            }
            update_pipeline_record($pipeline_id, 'failed', $metadata, $error);
        }
    );
} else {
    print "Status: 404 Not Found\n\n";
}

sub update_pipeline_record {
    my ($pipeline_id, $status, $metadata, $error) = @_;
    # Update in your database
    # Use $metadata to correlate with your application state
    # e.g., UPDATE pipelines SET status = ? WHERE user_id = ? AND job_type = ?
}
```

### Web Framework Integration (Mojolicious)

```perl
package MyApp::Controller::Webhook;
use Mojo::Base 'Mojolicious::Controller';

sub pipeline_webhook {
    my $c = shift;
    my $client = FileServerSdk::Client->new();
    
    if ($c->req->method eq 'POST') {
        my $success = 0;
        
        $client->handle_webhook(
            sub {
                my ($pipeline_id, $metadata) = @_;
                $c->app->log->info("Pipeline $pipeline_id completed");
                update_db($pipeline_id, 'completed', $metadata);
                $success = 1;
            },
            sub {
                my ($pipeline_id, $error, $metadata) = @_;
                $c->app->log->error("Pipeline $pipeline_id failed: $error");
                update_db($pipeline_id, 'failed', $metadata, $error);
                $success = 1;
            }
        );
        
        if ($success) {
            return $c->render(
                json => { status => 'processed' },
                status => 200
            );
        } else {
            return $c->render(
                json => { status => 'error' },
                status => 400
            );
        }
    }
    
    $c->render(status => 404);
}

sub update_db {
    my ($pipeline_id, $status, $metadata, $error) = @_;
    # Update database with $metadata to correlate pipeline with application state
}

1;
```

### Web Framework Integration (Catalyst)

```perl
package MyApp::Controller::API;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }

sub webhook : Local : ActionClass('REST') {
    my ($self, $c) = @_;
}

sub webhook_POST {
    my ($self, $c) = @_;
    my $client = FileServerSdk::Client->new();
    
    my $success = 0;
    
    $client->handle_webhook(
        sub {
            my ($pipeline_id, $metadata) = @_;
            $c->log->info("Pipeline $pipeline_id completed");
            update_db($pipeline_id, 'completed', $metadata);
            $success = 1;
        },
        sub {
            my ($pipeline_id, $error, $metadata) = @_;
            $c->log->error("Pipeline $pipeline_id failed: $error");
            update_db($pipeline_id, 'failed', $metadata, $error);
            $success = 1;
        }
    );
    
    if ($success) {
        $c->stash(status => 'processed');
    } else {
        $c->res->status(400);
        $c->stash(status => 'error');
    }
}

sub update_db {
    my ($pipeline_id, $status, $metadata, $error) = @_;
    # Update database with $metadata to correlate pipeline with application state
}

__PACKAGE__->meta->make_immutable;
1;
```

## Advanced Callback Handling with Database Integration

### Example: Pre-allocation Pattern

This pattern demonstrates how to reserve resources before pipeline execution:

```perl
use FileServerSdk::Client;
use DBI;

my $dbh = DBI->connect('dbi:mysql:myapp', 'user', 'pass');
my $client = FileServerSdk::Client->new();

# Step 1: Generate ID and pre-allocate resources
my $pipeline_id = $client->gen_uuid();
my $user_id = CGI::param('user_id');
my $output_key = "processed/$user_id/$pipeline_id/output.pdf";

eval {
    # Reserve space in database
    my $sth = $dbh->prepare(q{
        INSERT INTO pipeline_jobs 
        (pipeline_id, user_id, status, output_key, created_at)
        VALUES (?, ?, 'pending', ?, NOW())
    });
    $sth->execute($pipeline_id, $user_id, $output_key);
};

if ($@) {
    die "Failed to reserve pipeline: $@\n";
}

# Step 2: Build and execute pipeline
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => \@input_files,
    output_file => $output_key
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

my $webhook_url = 'https://your-app.com/api/webhook?action=webhook&secret='.$ENV{PIPELINE_SHARED_SECRET};

# Step 3: Prepare metadata to pass to pipeline
my $metadata = {
    user_id => $user_id,
    output_key => $output_key,
    job_type => 'pdf_merge',
};

# Step 4: Execute with webhook and metadata
my $result = $client->execute_pipeline(
    $pipeline_id,
    $pipeline,
    $webhook_url
);

print "Pipeline queued with ID: $result\n";
```

### Example: Database Update on Completion

```perl
use FileServerSdk::Client;
use DBI;

my $dbh = DBI->connect('dbi:mysql:myapp', 'user', 'pass');
my $client = FileServerSdk::Client->new();

my $on_success = sub {
    my ($pipeline_id, $metadata) = @_;
    
    eval {
        # Update status
        my $sth = $dbh->prepare(q{
            UPDATE pipeline_jobs 
            SET status = 'completed', completed_at = NOW()
            WHERE pipeline_id = ?
        });
        $sth->execute($pipeline_id);
        
        # Store completion metrics
        $sth = $dbh->prepare(q{
            INSERT INTO pipeline_metrics 
            (pipeline_id, execution_time, status)
            VALUES (?, ?, 'success')
        });
        my $exec_time = time() - (retrieve_created_time($pipeline_id) || 0);
        $sth->execute($pipeline_id, $exec_time);
    };
    
    if ($@) {
        warn "Error in success callback: $@\n";
    }
};

my $on_error = sub {
    my ($pipeline_id, $error) = @_;
    
    eval {
        # Update status and error
        my $sth = $dbh->prepare(q{
            UPDATE pipeline_jobs 
            SET status = 'failed', error_message = ?, failed_at = NOW()
            WHERE pipeline_id = ?
        });
        $sth->execute($error, $pipeline_id);
        
        # Log error metrics
        $sth = $dbh->prepare(q{
            INSERT INTO pipeline_metrics 
            (pipeline_id, error_message, status)
            VALUES (?, ?, 'failed')
        });
        $sth->execute($pipeline_id, $error);
    };
    
    if ($@) {
        warn "Error in error callback: $@\n";
    }
};

$client->handle_webhook($on_success, $on_error);
```

### Example: Event Logging and Notifications

```perl
my $on_success = sub {
    my ($pipeline_id, $metadata) = @_;
    
    eval {
        # Get pipeline details
        my $job = get_pipeline_job($pipeline_id);
        
        # Log event with metadata
        log_event({
            event_type => 'pipeline_success',
            pipeline_id => $pipeline_id,
            user_id => $job->{user_id},
            metadata => $metadata,
            timestamp => time(),
            duration => time() - $job->{created_at},
        });
        
        # Send notification
        notify_user($job->{user_id}, 
            "Your document processing is complete");
        
        # Update database
        update_pipeline_job($pipeline_id, 'completed');
    };
    
    if ($@) {
        warn "Error in success callback: $@\n";
    }
};

my $on_error = sub {
    my ($pipeline_id, $error, $metadata) = @_;
    
    eval {
        my $job = get_pipeline_job($pipeline_id);
        
        # Log event with metadata for better context
        log_event({
            event_type => 'pipeline_error',
            pipeline_id => $pipeline_id,
            user_id => $job->{user_id},
            metadata => $metadata,
            timestamp => time(),
            error => $error,
        });
        
        # Send notification
        notify_user($job->{user_id}, 
            "Document processing failed: $error");
        
        # Update database
        update_pipeline_job($pipeline_id, 'failed', $error);
    };
    
    if ($@) {
        warn "Error in error callback: $@\n";
    }
};

$client->handle_webhook($on_success, $on_error);
```

## Webhook URL Requirements

### URL Format

The webhook URL should:
- Be publicly accessible from the pipeline server
- Accept HTTP POST requests
- Include any necessary parameters for routing (e.g., `action=webhook`)
- Optionally include the shared secret (though it's also passed as a parameter)

**Example URLs:**
```
https://your-app.com/api/webhook?action=webhook
https://myservice.example.com/pipeline/callback?token=secret
```

### How the Server Calls Your Webhook

The pipeline server makes a POST request with these parameters:

```
POST https://your-app.com/api/webhook?action=webhook

Parameters:
  - secret: <PIPELINE_SHARED_SECRET>
  - pipelineId: <pipeline_id>
  - status: 'completed' | 'failed' | ...
  - error: <error_message> (only if status indicates failure)
```

### Security

The webhook is verified using:
1. **Shared Secret**: The `secret` parameter must match `PIPELINE_SHARED_SECRET`
2. **HTTPS**: Use HTTPS in production for security
3. **POST method**: Webhooks are always POST requests
4. **Idempotency**: Design callbacks to be idempotent (safe to call multiple times)

## Using Metadata in Webhooks

Metadata provides a way to attach application-specific context to pipeline executions. When you execute a pipeline with metadata, that metadata is returned in the webhook callbacks, allowing you to correlate pipeline events with your application state without requiring database lookups.

### Submitting Metadata

Pass a hash reference as the fourth parameter to `execute_pipeline`:

```perl
my $metadata = {
    user_id => $user_id,
    job_id => $job_id,
    request_id => 'req-abc123',
    custom_context => 'any_value',
};

my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-app.com/webhook',
    $metadata  # Pass metadata as fourth parameter
);
```

### Accessing Metadata in Callbacks

The metadata is passed to both success and failure callbacks:

```perl
$client->handle_webhook(
    sub {
        my ($pipeline_id, $metadata) = @_;
        
        # $metadata is a hash reference containing the data you submitted
        if (defined $metadata) {
            my $user_id = $metadata->{user_id};
            my $job_id = $metadata->{job_id};
            
            # Use metadata for correlation without DB lookup
            update_job_status($job_id, 'completed');
        }
    },
    sub {
        my ($pipeline_id, $error, $metadata) = @_;
        
        # Metadata is also available on failure
        if (defined $metadata) {
            notify_user($metadata->{user_id}, 
                "Job $metadata->{job_id} failed: $error");
        }
    }
);
```

### Metadata Best Practices

1. **Keep it Small**: Store only necessary identifiers and context
2. **Use Simple Values**: Prefer strings and numbers over complex structures
3. **Document Your Keys**: Clearly define what metadata fields you use
4. **Handle Missing Metadata**: Always check if metadata is defined before using it
5. **Avoid Sensitive Data**: Don't store passwords or tokens in metadata

## Complete Example: Document Processing Application

```perl
#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard -utf8/;
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;
use DBI;

my $dbh = DBI->connect('dbi:mysql:app', 'user', 'pass');
my $client = FileServerSdk::Client->new();
my $action = param('action') || 'process';

if ($action eq 'process') {
    # User submitted a job
    my @file_ids = split(',', param('files'));
    my $user_id = param('user_id');
    
    eval {
        # Generate unique ID
        my $pipeline_id = $client->gen_uuid();
        
        # Create database record
        my $sth = $dbh->prepare(q{
            INSERT INTO jobs (job_id, user_id, status, created_at)
            VALUES (?, ?, 'pending', NOW())
        });
        $sth->execute($pipeline_id, $user_id);
        
        # Map file IDs to S3 paths
        my @s3_files = map { "uploads/$user_id/$_" } @file_ids;
        my $output_file = "processed/$user_id/$pipeline_id.pdf";
        
        # Create and execute pipeline
        my $task = FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => \@s3_files,
            output_file => $output_file
        );
        
        my $pipeline = FileServerSdk::SequentialPipeline->new()
            ->add_task_step($task);
        
        my $webhook_url = 'https://myapp.com/cgi-bin/process.pl?action=callback';
        
        my $result = $client->execute_pipeline(
            $pipeline_id,
            $pipeline,
            $webhook_url
        );
        
        print "Content-Type: application/json\n\n";
        print JSON::to_json({
            job_id => $result,
            status => 'queued'
        });
    };
    
    if ($@) {
        print "Content-Type: application/json\n";
        print "Status: 500\n\n";
        print JSON::to_json({ error => $@ });
    }
}
elsif ($action eq 'callback') {
    # Webhook callback from pipeline server
    $client->handle_webhook(
        sub {
            my ($pipeline_id) = @_;
            
            eval {
                my $sth = $dbh->prepare(q{
                    UPDATE jobs 
                    SET status = 'completed', completed_at = NOW()
                    WHERE job_id = ?
                });
                $sth->execute($pipeline_id);
            };
            
            warn "Error updating job: $@" if $@;
        },
        sub {
            my ($pipeline_id, $error) = @_;
            
            eval {
                my $sth = $dbh->prepare(q{
                    UPDATE jobs 
                    SET status = 'failed', error_msg = ?, failed_at = NOW()
                    WHERE job_id = ?
                });
                $sth->execute($error, $pipeline_id);
            };
            
            warn "Error updating job: $@" if $@;
        }
    );
}

1;
```

## Testing Webhooks

### Local Testing with ngrok

For local development, use ngrok to expose your local server:

```bash
# Start ngrok
ngrok http 3000

# Use the ngrok URL in your code
my $webhook_url = 'https://abc123.ngrok.io/api/webhook?action=webhook';

# You can now test locally with real pipeline callbacks
```

### Mock Testing

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FileServerSdk::Client;

# Test webhook handling with mock CGI parameters
{
    local $ENV{PIPELINE_SHARED_SECRET} = 'test_secret';
    
    # Mock CGI parameters
    my %mock_params = (
        secret => 'test_secret',
        pipelineId => '123abc',
        status => 'completed',
    );
    
    local *CGI::param = sub {
        my ($key) = @_;
        return $mock_params{$key} if defined $key;
        return keys %mock_params;
    };
    
    my $callback_called = 0;
    
    my $client = FileServerSdk::Client->new();
    $client->handle_webhook(
        sub {
            my ($pipeline_id) = @_;
            is($pipeline_id, '123abc', 'Correct pipeline ID passed');
            $callback_called = 1;
        }
    );
    
    ok($callback_called, 'Success callback was called');
}

done_testing();
```

### Error Webhook Testing

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FileServerSdk::Client;

# Test error webhook
{
    local $ENV{PIPELINE_SHARED_SECRET} = 'test_secret';
    
    my %mock_params = (
        secret => 'test_secret',
        pipelineId => '456def',
        status => 'failed',
        error => 'PDF merge failed: Invalid file format',
    );
    
    local *CGI::param = sub {
        my ($key) = @_;
        return $mock_params{$key} if defined $key;
        return keys %mock_params;
    };
    
    my $error_received;
    
    my $client = FileServerSdk::Client->new();
    $client->handle_webhook(
        undef,  # no success callback
        sub {
            my ($pipeline_id, $error) = @_;
            is($pipeline_id, '456def', 'Correct pipeline ID');
            like($error, qr/Invalid file format/, 'Correct error message');
            $error_received = 1;
        }
    );
    
    ok($error_received, 'Error callback was called');
}

done_testing();
```

## Best Practices

### 1. Always Generate IDs Before Execution

```perl
# Good - ID is known before execution
my $pipeline_id = $client->gen_uuid();
store_in_db($pipeline_id);
$client->execute_pipeline($pipeline_id, $pipeline, $webhook_url);

# Acceptable - ID generated by server (but harder to track)
my $result = $client->execute_pipeline($pipeline, $webhook_url);
```

### 2. Use Database to Track State

```perl
# Good - full audit trail
my $pipeline_id = $client->gen_uuid();
store_pipeline({
    id => $pipeline_id,
    user_id => $user_id,
    status => 'pending',
    files => \@files,
    created_at => time(),
});

$client->execute_pipeline($pipeline_id, $pipeline, $webhook_url);
```

### 3. Keep Callbacks Quick

```perl
# Good - quick database update
my $on_success = sub {
    my ($pipeline_id) = @_;
    update_status($pipeline_id, 'completed');
};

# Bad - slow operation
my $on_success = sub {
    my ($pipeline_id) = @_;
    process_large_file();  # Don't do heavy processing here
};

# Better - use background jobs
my $on_success = sub {
    my ($pipeline_id) = @_;
    queue_background_job('process_results', { pipeline_id => $pipeline_id });
};
```

### 4. Make Callbacks Idempotent

```perl
# Good - safe to call multiple times
my $on_success = sub {
    my ($pipeline_id) = @_;
    my $sth = $dbh->do(q{
        INSERT INTO pipeline_results (id, status)
        VALUES (?, 'completed')
        ON DUPLICATE KEY UPDATE status = 'completed'
    }, undef, $pipeline_id);
};

# Bad - fails if called twice
my $on_success = sub {
    my ($pipeline_id) = @_;
    my $sth = $dbh->prepare(q{
        INSERT INTO pipeline_results (id, status)
        VALUES (?, 'completed')
    });
    $sth->execute($pipeline_id);  # Dies on duplicate key
};
```

### 5. Log All Webhook Activity

```perl
my $on_success = sub {
    my ($pipeline_id) = @_;
    log_entry({
        type => 'webhook_success',
        pipeline_id => $pipeline_id,
        timestamp => time(),
    });
    update_status($pipeline_id, 'completed');
};

my $on_error = sub {
    my ($pipeline_id, $error) = @_;
    log_entry({
        type => 'webhook_error',
        pipeline_id => $pipeline_id,
        error => $error,
        timestamp => time(),
    });
    update_status($pipeline_id, 'failed', $error);
};
```

### 6. Handle Webhook Timeouts

```perl
my $on_success = sub {
    my ($pipeline_id) = @_;
    
    eval {
        local $SIG{ALRM} = sub { die "Timeout\n" };
        alarm(30);  # 30 second timeout
        
        # Database update (should be fast)
        update_status($pipeline_id, 'completed');
        
        alarm(0);
    };
    
    if ($@) {
        if ($@ =~ /Timeout/) {
            warn "Webhook callback timed out for $pipeline_id\n";
        } else {
            warn "Error in webhook callback: $@\n";
        }
    }
};
```

## Troubleshooting

### Webhook Not Firing

**Check:**
1. Webhook URL is publicly accessible
2. Firewall allows incoming POST requests
3. HTTPS certificate is valid
4. `PIPELINE_SHARED_SECRET` matches on both ends

```bash
# Test webhook URL manually
curl -X POST "https://your-app.com/api/webhook?action=webhook" \
  -d "secret=yoursecret&pipelineId=test123&status=completed"
```

### Pipeline ID Not Received in Callback

**Check:**
1. Pipeline ID is passed to `execute_pipeline()`
2. Callback function receives the parameter: `sub { my ($pipeline_id) = @_; }`
3. Server is sending the `pipelineId` parameter

```perl
# Debug callback
sub debug_callback {
    my ($pipeline_id) = @_;
    warn "DEBUG: Received pipeline ID: $pipeline_id\n";
    warn "DEBUG: Number of args: " . scalar(@_) . "\n";
}
```

### Database Updates Not Happening

**Check:**
1. Database connection is valid
2. Callback is being called (add logging)
3. SQL is correct and connection permissions are set
4. Callback is using the correct database handle

```perl
my $on_success = sub {
    my ($pipeline_id) = @_;
    warn "DEBUG: Success callback fired for $pipeline_id\n";
    
    eval {
        warn "DEBUG: About to update database\n";
        my $result = $dbh->do(
            "UPDATE jobs SET status = 'completed' WHERE job_id = ?",
            undef,
            $pipeline_id
        );
        warn "DEBUG: Update result: $result\n";
    };
    
    if ($@) {
        warn "DEBUG: Error in callback: $@\n";
    }
};
```
