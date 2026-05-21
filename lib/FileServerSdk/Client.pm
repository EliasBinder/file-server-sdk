package FileServerSdk::Client;
use strict;
use warnings;
use Net::Amazon::S3;
use Net::Amazon::S3::Authorization::Basic;
use Net::Amazon::S3::Vendor::Generic;
use JSON;
use HTTP::Tiny;
use CGI          qw/:standard -utf8/;
use MIME::Base64 qw(encode_base64);
use Digest::SHA  qw(hmac_sha256);
use POSIX        qw(strftime);

# Default configuration
my %DEFAULT_CONFIG = (
    s3_host           => 's3.primuss.de',
    pipeline_endpoint => 'https://pipeline-mgm.primuss.de/pipeline',
    metadata_endpoint => 'https://pipeline-mgm.primuss.de/metadata',
    default_expires   => 3_600,                                        # 1 hour
);

sub new {
    my ( $class, %args ) = @_;

    # Initialize config with defaults
    my %config = %DEFAULT_CONFIG;

    # Override with provided arguments or environment variables
    $config{access_key_id} = $args{access_key_id} || $ENV{ACCESS_KEY_ID};
    $config{secret_access_key} =
      $args{secret_access_key} || $ENV{SECRET_ACCESS_KEY};
    $config{pipeline_shared_secret} =
      $args{pipeline_shared_secret} || $ENV{PIPELINE_SHARED_SECRET};
    $config{s3_host} =
      $args{s3_host} || $ENV{S3_HOST} || $DEFAULT_CONFIG{s3_host};
    $config{pipeline_endpoint} =
         $args{pipeline_endpoint}
      || $ENV{PIPELINE_ENDPOINT}
      || $DEFAULT_CONFIG{pipeline_endpoint};
    $config{metadata_endpoint} =
         $args{metadata_endpoint}
      || $ENV{METADATA_ENDPOINT}
      || $DEFAULT_CONFIG{metadata_endpoint};

    # Validate required variables
    die
"ACCESS_KEY_ID is required (provide via argument or environment variable)\n"
      unless $config{access_key_id};
    die
"SECRET_ACCESS_KEY is required (provide via argument or environment variable)\n"
      unless $config{secret_access_key};
    die
"PIPELINE_SHARED_SECRET is required (provide via argument or environment variable)\n"
      unless $config{pipeline_shared_secret};

    # Manually create and initialize the hash reference
    my $self = {};

    # Store config in the object
    $self->{config} = \%config;

    # Copy other arguments into the hash
    foreach my $key ( keys %args ) {
        $self->{$key} = $args{$key}
          unless $key =~
/^(access_key_id|secret_access_key|pipeline_shared_secret|s3_host|pipeline_endpoint|metadata_endpoint)$/;
    }

    # Initialize the S3 client
    my $s3 = Net::Amazon::S3->new(
        authorization_context => Net::Amazon::S3::Authorization::Basic->new(
            aws_access_key_id     => $config{access_key_id},
            aws_secret_access_key => $config{secret_access_key},
        ),
        vendor => Net::Amazon::S3::Vendor::Generic->new(
            host                 => $config{s3_host},
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

sub download_file {
    my ( $self, $bucket, $key ) = @_;

    die "bucket is required\n" unless defined $bucket;
    die "key is required\n"    unless defined $key;

    my $bucket_obj = $self->s3->bucket($bucket);
    my $file       = $bucket_obj->get_key($key);

    if ( defined $file ) {
        return $file->{value};
    }
    else {
        die "File not found in bucket '$bucket' with key '$key'\n";
    }
}

sub upload_file {
    my ( $self, $bucket, $key, $content, $content_type ) = @_;

    die "bucket is required\n"       unless defined $bucket;
    die "key is required\n"          unless defined $key;
    die "content is required\n"      unless defined $content;
    die "content_type is required\n" unless defined $content_type;

    my $bucket_obj = $self->s3->bucket($bucket);
    my $response =
      $bucket_obj->add_key( $key, $content, { content_type => $content_type } );

    if ( defined $response ) {
        return 1;
    }
    else {
        die "Failed to upload file to bucket '$bucket' with key '$key'\n";
    }
}

sub delete_file {
    my ( $self, $bucket, $key ) = @_;

    die "bucket is required\n" unless defined $bucket;
    die "key is required\n"    unless defined $key;

    my $bucket_obj = $self->s3->bucket($bucket);
    my $response   = $bucket_obj->delete_key($key);

    if ( defined $response ) {
        return 1;
    }
    else {
        die "Failed to delete file from bucket '$bucket' with key '$key'\n";
    }
}

sub get_metadata {
    my ( $self, $bucket, $key ) = @_;

    die "bucket is required\n" unless defined $bucket;
    die "key is required\n"    unless defined $key;

    # Make a HTTP request to the metadata endpoint
    my $response = HTTP::Tiny->new->request(
        'GET',
        $self->{config}->{metadata_endpoint}
          . "?bucket=$bucket&key=$key&secret=$self->{config}->{pipeline_shared_secret}",
    );

    if ( $response->{success} ) {
        my $metadata = eval { $self->{json}->decode( $response->{content} ) };
        if ($@) {
            die "Failed to decode metadata JSON: $@\n";
        }
        return $metadata;
    }
    else {
        die "Failed to get metadata: "
          . $response->{status} . " "
          . $response->{reason} . "\n";
    }
}

sub set_metadata {
    my ( $self, $bucket, $key, $metadata ) = @_;

    die "bucket is required\n"   unless defined $bucket;
    die "key is required\n"      unless defined $key;
    die "metadata is required\n" unless defined $metadata;

    my $metadata_json = eval { $self->{json}->encode($metadata) };
    if ($@) {
        die "Failed to encode metadata to JSON: $@\n";
    }

    # Make a HTTP request to the metadata endpoint
    my $response = HTTP::Tiny->new->request(
        'PATCH',
        $self->{config}->{metadata_endpoint}
          . "?bucket=$bucket&key=$key&secret=$self->{config}->{pipeline_shared_secret}",
        {
            headers => { 'Content-Type' => 'application/json' },
            content => $metadata_json,
        }
    );

    if ( $response->{success} ) {
        return 1;
    }
    else {
        die "Failed to set metadata: "
          . $response->{status} . " "
          . $response->{reason} . "\n";
    }
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

    my $webhook_json;
    if ( defined $webhook_url ) {
        $webhook_json = {
            method => 'POST',
            url    => $webhook_url,
        };
    }

    # Build request body
    # Add "webhook" field only if webhook_url is provided, otherwise omit it
    my %req_body = ( steps => $pipeline_json, );

    # Add webhook info if provided
    if ( defined $webhook_url ) {
        $req_body{webhook} = {
            method => 'POST',
            url    => $webhook_url,
        };
    }

    my $json_body = $self->{json}->encode( \%req_body );

    # Send the request to the file server
    my $response = HTTP::Tiny->new->request(
        'PUT',
        $self->{config}->{pipeline_endpoint}
          . '?secret='
          . $self->{config}->{pipeline_shared_secret},
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
          . $response->{reason} . " "
          . $json_body . "\n";
    }
}

sub cleanup_pipeline {
    my ( $self, $pipeline ) = @_;

    die "pipeline is required\n" unless defined $pipeline;

    my @files = $pipeline->get_files();

    foreach my $file (@files) {
        eval { $self->delete_file( $file->{bucket}, $file->{key} ); };
        if ($@) {
            warn
"Failed to delete file from bucket '$file->{bucket}' with key '$file->{key}': $@\n";
        }
    }

    return 1;
}

sub handle_webhook {
    my ($self) = @_;

    # Get "secret" CGI Parameter
    my $secret          = CGI::param('secret');
    my $expected_secret = $self->{config}->{pipeline_shared_secret};

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
            print "Content-Type: application/json\n\n";
            print "{\"success\": true}\n";
            return 1;
        }
    }
    else {
        my $error = CGI::param('error') || 'Unknown error';
        if ( defined $callbacks->{on_error} ) {
            $callbacks->{on_error}->($error);
            print "Content-Type: application/json\n\n";
            print "{\"success\": true}\n";
            return 1;
        }
    }

    warn
"No appropriate callback found for pipelineId: $pipelineId with status: $status\n";
    return 0;
}

sub handle_generate_presigned_urls {
    my ( $self, $bucket, $config ) = @_;

    die "bucket is required\n" unless defined $bucket;

    my $min_files       = $config->{min_files};
    my $max_files       = $config->{max_files};
    my @supported_types = @{ $config->{content_types} || [] };
    my $expires_in      = $config->{expires_in} || 3_600;

    my $files_json = CGI::param('files');
    my @files      = ();

    if ($files_json) {
        eval {
            my $files_ref = $self->{json}->decode($files_json);
            if ( ref($files_ref) eq 'ARRAY' ) {
                @files = @{$files_ref};
            }
        };
        if ($@) {
            warn "Failed to decode files JSON: $@\n";
            return 0;
        }
    }

    if ( defined $min_files && @files < $min_files ) {
        warn "Number of files is less than the minimum required: $min_files\n";
        return 0;
    }
    if ( defined $max_files && @files > $max_files ) {
        warn
          "Number of files is greater than the maximum allowed: $max_files\n";
        return 0;
    }

    # Compute once for all files
    my $now      = time();
    my $date_ymd = strftime( '%Y%m%d',         gmtime($now) );
    my $date_iso = strftime( '%Y%m%dT%H%M%SZ', gmtime($now) );
    my $expiration =
      strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime( $now + $expires_in ) );
    my $region = 'us-east-1';
    my $credential =
      "$self->{config}->{access_key_id}/$date_ymd/$region/s3/aws4_request";
    my $signing_key = _derive_signing_key( $self->{config}->{secret_access_key},
        $date_ymd, $region, 's3' );

    my @presigned_urls;

    foreach my $file (@files) {
        my $ct = $file->{content_type} || 'application/octet-stream';

        # Find matching type config
        my $type_config;
        if (@supported_types) {
            foreach my $type (@supported_types) {
                if ( $type->{type} eq $ct ) {
                    $type_config = $type;
                    last;
                }
            }
            unless ( defined $type_config ) {
                warn "Content type '$ct' is not allowed\n";
                next;
            }
        }

        # Safe to access now that $type_config existence is confirmed
        my $max_file_size =
          ( defined $type_config && defined $type_config->{limit} )
          ? $type_config->{limit}
          : 10 * 1024 * 1024;

        if ( defined $file->{size} && $file->{size} > $max_file_size ) {
            warn "File size for '$ct' exceeds limit of $max_file_size bytes\n";
            next;
        }

        my $uuid = gen_uuid();

        my $policy = {
            expiration => $expiration,
            conditions => [
                { bucket             => $bucket },
                { key                => $uuid },
                { acl                => 'private' },
                { 'Content-Type'     => $ct },
                { 'x-amz-algorithm'  => 'AWS4-HMAC-SHA256' },
                { 'x-amz-credential' => $credential },
                { 'x-amz-date'       => $date_iso },
                [ 'content-length-range', 1, $max_file_size ],
            ],
        };

        my $policy_json = encode_json($policy);
        my $policy_b64  = encode_base64( $policy_json, '' );
        my $signature =
          unpack( 'H*', hmac_sha256( $policy_b64, $signing_key ) );

        push @presigned_urls,
          {
            index  => $file->{index},
            uuid   => $uuid,
            url    => "https://" . $self->{config}->{s3_host} . "/$bucket",
            fields => {
                key                => $uuid,
                acl                => 'private',
                'Content-Type'     => $ct,
                'x-amz-algorithm'  => 'AWS4-HMAC-SHA256',
                'x-amz-credential' => $credential,
                'x-amz-date'       => $date_iso,
                policy             => $policy_b64,
                'x-amz-signature'  => $signature,
            },
          };
    }

    my $response_json = $self->{json}->encode(
        {
            success   => JSON::true,
            timestamp => time(),
            urls      => \@presigned_urls,
        }
    );
    print "Content-Type: application/json\n\n";
    print $response_json;

    return \@presigned_urls;
}

sub _derive_signing_key {
    my ( $secret, $date, $region, $service ) = @_;
    my $k_date    = hmac_sha256( $date,          "AWS4$secret" );
    my $k_region  = hmac_sha256( $region,        $k_date );
    my $k_service = hmac_sha256( $service,       $k_region );
    my $k_signing = hmac_sha256( 'aws4_request', $k_service );
    return $k_signing;
}

# Private helper function for UUID generation
sub gen_uuid {
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

sub _hmac_sha256_hex {
    my ( $key, $data ) = @_;
    return Digest::HMAC::hmac( $data, $key, \&Digest::SHA::sha256 );
}

1;
