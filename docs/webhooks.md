# Webhooks and Callbacks Guide

Webhooks allow your application to receive real-time notifications when pipelines complete or fail. This guide explains how to implement and handle webhooks.

## How Webhooks Work

When you execute a pipeline with a webhook URL and callbacks:

1. Your application registers callbacks with the client
2. The client sends the pipeline to the server with the webhook URL
3. The pipeline server executes the pipeline asynchronously
4. Upon completion (success or failure), the server makes an HTTP POST request to your webhook URL
5. Your application's webhook handler processes the callback and executes the appropriate callback function

## Setting Up Webhooks

### Basic Webhook Execution

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

# Execute with webhook
my $pipeline_id = $client->execute_pipeline(
    $pipeline,
    'https://your-app.com/api/webhook?action=webhook',
    sub {
        # Success callback
        print "Pipeline $pipeline_id completed successfully!\n";
    },
    sub {
        # Error callback
        my ($error) = @_;
        print "Pipeline $pipeline_id failed: $error\n";
    }
);

print "Pipeline ID: $pipeline_id\n";
```

## Webhook Handlers

### Simple CGI Webhook Handler

```perl
#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard -utf8/;
use FileServerSdk::Client;

my $action = param('action');
my $client = FileServerSdk::Client->new();

if ($action eq 'webhook') {
    # Handle the webhook callback
    my $result = $client->handle_webhook();
    
    if ($result) {
        print header('application/json');
        print '{"status":"success"}';
    } else {
        print header(-status => '400 Bad Request', 'application/json');
        print '{"status":"error"}';
    }
} else {
    print header(-status => '404 Not Found');
    print 'Not found';
}
```

### Web Framework Integration (Mojolicious)

```perl
package MyApp::WebhookController;
use Mojo::Base 'Mojolicious::Controller';

sub webhook {
    my $c = shift;
    my $client = FileServerSdk::Client->new();
    
    if ($c->req->method eq 'POST') {
        my $result = $client->handle_webhook();
        
        if ($result) {
            return $c->render(
                json => { status => 'success' },
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
    
    my $result = $client->handle_webhook();
    
    if ($result) {
        $c->stash(status => 'success');
    } else {
        $c->res->status(400);
        $c->stash(status => 'error');
    }
}

__PACKAGE__->meta->make_immutable;
1;
```

## Callback Functions

### Success Callback

The success callback is called when a pipeline completes successfully:

```perl
my $success_callback = sub {
    my () = @_;  # No parameters passed
    
    # Perform actions after successful pipeline execution
    print "Pipeline execution completed!\n";
    
    # Download results
    my $result = $client->download_file('bucket', 'output.pdf');
    
    # Update database
    update_database_status('completed');
    
    # Send notification
    send_email_notification('Pipeline completed successfully');
};
```

### Error Callback

The error callback is called when a pipeline fails:

```perl
my $error_callback = sub {
    my ($error) = @_;
    
    # Handle the error
    warn "Pipeline execution failed: $error\n";
    
    # Log error
    log_error($error);
    
    # Update database
    update_database_status('failed', $error);
    
    # Send alert
    send_alert_email("Pipeline failed: $error");
    
    # Clean up temporary files
    eval {
        $client->cleanup_pipeline($pipeline);
    };
};
```

## Advanced Callback Handling

### Callback with Database Updates

```perl
use DBI;

my $dbh = DBI->connect('dbi:mysql:myapp', 'user', 'pass');

my $client = FileServerSdk::Client->new();

my $on_success = sub {
    eval {
        # Update database
        my $sth = $dbh->prepare('UPDATE jobs SET status = ? WHERE pipeline_id = ?');
        $sth->execute('completed', $pipeline_id);
        
        # Download results
        my $result = $client->download_file('bucket', 'output.pdf');
        
        # Save results
        $sth = $dbh->prepare('UPDATE jobs SET result = ? WHERE pipeline_id = ?');
        $sth->execute($result, $pipeline_id);
    };
    
    if ($@) {
        warn "Error in success callback: $@\n";
    }
};

my $on_error = sub {
    my ($error) = @_;
    
    eval {
        my $sth = $dbh->prepare('UPDATE jobs SET status = ?, error_msg = ? WHERE pipeline_id = ?');
        $sth->execute('failed', $error, $pipeline_id);
    };
    
    if ($@) {
        warn "Error in error callback: $@\n";
    }
};

$client->execute_pipeline($pipeline, $webhook_url, $on_success, $on_error);
```

### Callback with Event Logging

```perl
my $on_success = sub {
    eval {
        log_event({
            event_type => 'pipeline_success',
            pipeline_id => $pipeline_id,
            timestamp => time(),
            details => 'Pipeline execution completed',
        });
        
        # Process results
        process_pipeline_results($pipeline_id);
    };
    
    if ($@) {
        warn "Error in success callback: $@\n";
    }
};

my $on_error = sub {
    my ($error) = @_;
    
    eval {
        log_event({
            event_type => 'pipeline_error',
            pipeline_id => $pipeline_id,
            timestamp => time(),
            error => $error,
        });
        
        # Notify administrators
        notify_admins("Pipeline $pipeline_id failed: $error");
    };
    
    if ($@) {
        warn "Error in error callback: $@\n";
    }
};

$client->execute_pipeline($pipeline, $webhook_url, $on_success, $on_error);
```

## Webhook URL Requirements

### URL Format

The webhook URL should:
- Be publicly accessible from the pipeline server
- Accept HTTP POST requests
- Include the `action=webhook` parameter
- Include the `secret` parameter that matches `PIPELINE_SHARED_SECRET`

**Example URL:**
```
https://your-app.com/api/webhook?action=webhook
```

### Configuration

```perl
my $webhook_url = 'https://your-app.com/api/webhook?action=webhook';

# The client will POST with these parameters:
# - secret: $ENV{PIPELINE_SHARED_SECRET}
# - pipelineId: <pipeline_id>
# - status: 'completed' or other status
# - error: <error_message> (if status is not completed)
```

### Security

The webhook URL is verified using:
1. **Shared Secret**: The `secret` parameter must match `PIPELINE_SHARED_SECRET`
2. **HTTPS**: Use HTTPS in production for security
3. **POST method**: Webhooks are always POST requests

## Testing Webhooks

### Local Testing with ngrok

For local development, use ngrok to expose your local server:

```bash
# Start ngrok
ngrok http 3000

# Use the ngrok URL in your code
my $webhook_url = 'https://abc123.ngrok.io/api/webhook?action=webhook';
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
    local *CGI::param = sub {
        my ($key) = @_;
        my %params = (
            secret => 'test_secret',
            pipelineId => '123abc',
            status => 'completed',
        );
        return $params{$key};
    };
    
    my $client = FileServerSdk::Client->new();
    my $result = $client->handle_webhook();
    
    ok($result, 'Webhook handled successfully');
}

done_testing();
```

## Error Handling in Webhooks

### Timeout Handling

```perl
my $on_success = sub {
    eval {
        local $SIG{ALRM} = sub { die "Timeout\n" };
        alarm(30);  # 30 second timeout
        
        # Long-running operation
        process_pipeline_results($pipeline_id);
        
        alarm(0);
    };
    
    if ($@) {
        if ($@ =~ /Timeout/) {
            warn "Success callback timed out\n";
        } else {
            warn "Error in success callback: $@\n";
        }
    }
};
```

### Retry Logic

```perl
sub execute_with_retry {
    my ($callback, $max_attempts) = @_;
    $max_attempts ||= 3;
    
    for my $attempt (1..$max_attempts) {
        eval {
            $callback->();
            return;  # Success
        };
        
        if ($@) {
            warn "Attempt $attempt failed: $@\n";
            
            if ($attempt < $max_attempts) {
                my $delay = 2 ** $attempt;  # Exponential backoff
                sleep($delay);
            } else {
                die "All attempts failed: $@\n";
            }
        }
    }
}

# Usage
my $on_success = sub {
    execute_with_retry(sub {
        process_pipeline_results($pipeline_id);
    });
};
```

## Best Practices

### 1. Keep Callbacks Quick

```perl
# Good - quick operation
my $on_success = sub {
    log_event('Pipeline completed');
};

# Bad - slow operation
my $on_success = sub {
    # Processing 1GB file...
    process_large_file();
};
```

### 2. Use Background Jobs

```perl
# Better - queue for background processing
my $on_success = sub {
    my $job_queue = Job::Queue->new();
    $job_queue->enqueue({
        type => 'process_results',
        pipeline_id => $pipeline_id,
    });
    
    log_event('Pipeline completed, job queued');
};
```

### 3. Validate Webhook Input

```perl
my $client = FileServerSdk::Client->new();

# The client already validates the secret
# But you can add additional validation
sub validate_webhook {
    my $pipeline_id = CGI::param('pipelineId');
    my $status = CGI::param('status');
    
    die "Invalid pipeline ID" unless $pipeline_id =~ /^[a-z0-9]+$/;
    die "Invalid status" unless $status =~ /^(completed|failed)$/;
    
    return 1;
}

eval {
    validate_webhook();
    $client->handle_webhook();
};
```

### 4. Log All Webhook Activity

```perl
my $on_success = sub {
    log_webhook_event({
        status => 'success',
        pipeline_id => $pipeline_id,
        timestamp => time(),
        callback_duration => time() - $start_time,
    });
};

my $on_error = sub {
    my ($error) = @_;
    
    log_webhook_event({
        status => 'error',
        pipeline_id => $pipeline_id,
        error => $error,
        timestamp => time(),
    });
};
```

### 5. Handle Idempotency

```perl
# Webhooks may be called multiple times
# Use idempotent operations
my $on_success = sub {
    eval {
        # Use "INSERT ON DUPLICATE KEY UPDATE" or similar
        my $result = $dbh->do(q{
            INSERT INTO pipeline_results (pipeline_id, status, timestamp)
            VALUES (?, 'completed', now())
            ON DUPLICATE KEY UPDATE
            status = 'completed', timestamp = now()
        }, undef, $pipeline_id);
    };
};
```
