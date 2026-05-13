package FileServerSdk::Client;
use strict;
use warnings;
use Net::Amazon::S3;
use Net::Amazon::S3::Authorization::Basic;
use Net::Amazon::S3::Vendor::Generic;
use JSON;
use HTTP::Tiny;
use CGI qw/:standard -utf8/;

# Configuration
my %CONFIG = (
    s3_host => $ENV{S3_HOST}
      || 's3.primuss.de',
    pipeline_endpoint => $ENV{PIPELINE_ENDPOINT}
      || 'https://pipeline-mgm.primuss.de/pipeline',
    default_expires => 3_600,    # 1 hour
);

sub new {
    my ( $class, %args ) = @_;

    # Validate required environment variables
    die "ACCESS_KEY_ID environment variable is required\n"
      unless $ENV{ACCESS_KEY_ID};
    die "SECRET_ACCESS_KEY environment variable is required\n"
      unless $ENV{SECRET_ACCESS_KEY};
    die "PIPELINE_SHARED_SECRET environment variable is required\n"
      unless $ENV{PIPELINE_SHARED_SECRET};

    # Manually create and initialize the hash reference
    my $self = {};

    # Copy arguments into the hash
    foreach my $key ( keys %args ) {
        $self->{$key} = $args{$key};
    }

    # Initialize the S3 client
    my $s3 = Net::Amazon::S3->new(
        authorization_context => Net::Amazon::S3::Authorization::Basic->new(
            aws_access_key_id     => $ENV{ACCESS_KEY_ID},
            aws_secret_access_key => $ENV{SECRET_ACCESS_KEY},
        ),
        vendor => Net::Amazon::S3::Vendor::Generic->new(
            host                 => $CONFIG{s3_host},
            use_virtual_host     => 0,
            use_https            => 1,
            default_region       => 'us-east-1',
            authorization_method => 'Net::Amazon::S3::Signature::V4',
        ),
        retry => 1,
    );

    $self->{s3} = $s3;

    # JSON encoder
    $self->{json} = JSON->new->allow_nonref;

    # Hash for storing callbacks - key is pipelineId, value is callbacks hashref
    $self->{callbacks} = {};

    # Manually bless the reference into the class
    bless $self, $class;

    return $self;
}

sub s3 {
    my ( $self, $s3 ) = @_;
    if ( defined $s3 ) {
        $self->{s3} = $s3;
    }
    return $self->{s3};
}

sub execute_pipeline {
    my ( $self, $pipeline, $webhook_url, $on_success, $on_error ) = @_;

    # Validate required inputs
    die "pipeline is required\n" unless defined $pipeline;

    # Validate webhook and callbacks are both provided or both omitted
    if ( defined $webhook_url || defined $on_success || defined $on_error ) {
        die "webhook_url is required if callbacks are provided\n"
          unless defined $webhook_url;
        die "on_success callback is required if webhook_url is provided\n"
          unless defined $on_success && ref($on_success) eq 'CODE';
        die "on_error callback is required if webhook_url is provided\n"
          unless defined $on_error && ref($on_error) eq 'CODE';
    }

    # Convert the pipeline to JSON
    my $pipeline_json = $pipeline->to_json();

    # Build request body
    my %req_body = ( pipeline => $pipeline_json, );

    # Add webhook info if provided
    if ( defined $webhook_url ) {
        $req_body{webhook} = {
            method            => 'POST',
            url               => $webhook_url,
            additionalHeaders => {
                'Content-Type' => 'application/json',
            }
        };
    }

    my $json_body = $self->{json}->encode( \%req_body );

    # Send the request to the file server
    my $response = HTTP::Tiny->new->request(
        'PUT',
        $CONFIG{pipeline_endpoint} . '?secret=' . $ENV{PIPELINE_SHARED_SECRET},
        {
            headers => { 'Content-Type' => 'application/json' },
            content => $json_body,
        }
    );

    # Check the response
    if ( $response->{success} ) {
        my $response_data =
          eval { $self->{json}->decode( $response->{content} ) };
        if ($@) {
            die "Failed to decode response JSON: $@\n";
        }
        if ( exists $response_data->{pipelineId} ) {
            my $pipelineId = $response_data->{pipelineId};

            # Store the callbacks if webhook was provided
            if ( defined $webhook_url ) {
                $self->{callbacks}->{$pipelineId} = {
                    on_success => $on_success,
                    on_error   => $on_error,
                };
            }

            return $pipelineId;
        }
        else {
            die "Response does not contain pipelineId: "
              . $response->{content} . "\n";
        }
    }
    else {
        die "Failed to execute pipeline: "
          . $response->{status} . " "
          . $response->{reason} . "\n";
    }
}

sub handle_webhook {
    my ($self) = @_;

    # Get "secret" CGI Parameter
    my $secret          = CGI::param('secret');
    my $expected_secret = $ENV{PIPELINE_SHARED_SECRET};

    # Verify the secret
    unless ( defined $secret && $secret eq $expected_secret ) {
        warn "Received webhook with invalid secret\n";
        return 0;
    }

    # Read parameters from the request
    my $pipelineId = CGI::param('pipelineId');
    my $status     = CGI::param('status');

    unless ( defined $pipelineId && defined $status ) {
        warn "Missing required webhook parameters\n";
        return 0;
    }

    # Retrieve the callbacks for the given pipelineId
    my $callbacks = $self->{callbacks}->{$pipelineId};

    unless ( defined $callbacks ) {
        warn "No callbacks found for pipelineId: $pipelineId\n";
        return 0;
    }

    # Execute appropriate callback based on status
    if ( $status eq 'completed' ) {
        if ( defined $callbacks->{on_success} ) {
            $callbacks->{on_success}->();
            return 1;
        }
    }
    else {
        my $error = CGI::param('error') || 'Unknown error';
        if ( defined $callbacks->{on_error} ) {
            $callbacks->{on_error}->($error);
            return 1;
        }
    }

    warn
"No appropriate callback found for pipelineId: $pipelineId with status: $status\n";
    return 0;
}

sub handle_generate_presigned_urls {
    my ( $self, $bucket, $content_types, $num_files, $expires_in, $on_finish )
      = @_;

    die "bucket is required\n" unless defined $bucket;

    my $files_json = CGI::param('files');
    my @files      = ();
    my $files_ref;

    # Parse JSON
    if ($files_json) {
        eval {
            $files_ref = $self->{json}->decode($files_json);
            if ( ref($files_ref) eq 'ARRAY' ) {
                @files = @{$files_ref};
            }
        };
        if ($@) {
            warn "Failed to decode files JSON: $@\n";
            return 0;
        }
    }

    # Check if the number of files matches the expected number (if provided)
    if ( defined $num_files && @files != $num_files ) {
        warn "Expected $num_files files, but received " . scalar(@files) . "\n";
        return 0;
    }

    my @presigned_urls;
    my $bucket_obj = $self->s3->bucket($bucket);

    foreach my $file (@files) {

        # Generate a uuid for the file key to avoid collisions
        my $uuid = _gen_uuid();

        my $ct = $file->{content_type} || 'application/octet-stream';

        # Check if the content type is allowed (if provided)
        if ( defined $content_types && ref($content_types) eq 'ARRAY' ) {
            unless ( grep { $_ eq $ct } @{$content_types} ) {
                warn "Content type '$ct' is not allowed for file index "
                  . $file->{index} . "\n";
                next;
            }
        }

        my $expires_at = time +
          ( defined $expires_in ? $expires_in : $CONFIG{default_expires} );
        my $url = $bucket_obj->query_string_authentication_uri(
            key          => $uuid,
            expires_at   => $expires_at,
            method       => 'PUT',
            content_type => $ct
        );

        push @presigned_urls,
          {
            index => $file->{index},
            url   => $url
          };
    }

    my $response_json = $self->{json}->encode( \@presigned_urls );
    print "Content-Type: application/json\n\n";
    print $response_json;

    if ( defined $on_finish && ref($on_finish) eq 'CODE' ) {
        $on_finish->( \@presigned_urls );
    }

    return 1;
}

# Private helper function for UUID generation
sub _gen_uuid {
    my @chars = ( 'a' .. 'f', 0 .. 9 );
    my $uuid  = '';
    for ( 1 .. 8 ) { $uuid .= $chars[ rand @chars ] }
    $uuid .= '-';
    for ( 1 .. 4 ) { $uuid .= $chars[ rand @chars ] }
    $uuid .= '-4';
    for ( 1 .. 3 ) { $uuid .= $chars[ rand @chars ] }
    $uuid .= '-';
    $uuid .= sprintf( "%x", ( rand(4) + 8 ) );
    for ( 1 .. 3 ) { $uuid .= $chars[ rand @chars ] }
    $uuid .= '-';
    for ( 1 .. 12 ) { $uuid .= $chars[ rand @chars ] }
    return $uuid;
}

1;
