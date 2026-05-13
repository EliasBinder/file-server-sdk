#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Set up required environment variables
$ENV{ACCESS_KEY_ID}          = 'test_key_id';
$ENV{SECRET_ACCESS_KEY}      = 'test_secret_key';
$ENV{PIPELINE_SHARED_SECRET} = 'test_shared_secret';

require_ok('FileServerSdk::Client');
require_ok('FileServerSdk::SequentialPipeline');
require_ok('FileServerSdk::Tasks::PdfMergerTask');

# Test 1: new() constructor
subtest 'Client constructor' => sub {
    my $client = FileServerSdk::Client->new();
    isa_ok( $client, 'FileServerSdk::Client', 'Client object created' );
    ok( defined $client->s3(), 'S3 client initialized' );
    ok( $client,               'Client is defined' );
};

# Test 2: Missing environment variables
subtest 'Missing environment variables' => sub {
    local %ENV = %ENV;
    delete $ENV{ACCESS_KEY_ID};

    eval { FileServerSdk::Client->new(); };
    like(
        $@,
        qr/ACCESS_KEY_ID environment variable is required/,
        'Dies when ACCESS_KEY_ID is missing'
    );
};

subtest 'Missing SECRET_ACCESS_KEY' => sub {
    local %ENV = %ENV;
    delete $ENV{SECRET_ACCESS_KEY};

    eval { FileServerSdk::Client->new(); };
    like(
        $@,
        qr/SECRET_ACCESS_KEY environment variable is required/,
        'Dies when SECRET_ACCESS_KEY is missing'
    );
};

subtest 'Missing PIPELINE_SHARED_SECRET' => sub {
    local %ENV = %ENV;
    delete $ENV{PIPELINE_SHARED_SECRET};

    eval { FileServerSdk::Client->new(); };
    like(
        $@,
        qr/PIPELINE_SHARED_SECRET environment variable is required/,
        'Dies when PIPELINE_SHARED_SECRET is missing'
    );
};

# Test 3: s3() accessor/mutator
subtest 's3 accessor and mutator' => sub {
    my $client = FileServerSdk::Client->new();
    my $s3_obj = $client->s3();
    ok( defined $s3_obj, 's3() returns S3 object' );

    # Test mutator
    my $new_s3 = 'mock_s3';
    $client->s3($new_s3);
    is( $client->s3(), 'mock_s3', 's3() can set new S3 object' );
};

# Test 4: execute_pipeline with validation
subtest 'execute_pipeline validation' => sub {
    my $client = FileServerSdk::Client->new();

    # Test missing pipeline parameter
    eval { $client->execute_pipeline(undef); };
    like( $@, qr/pipeline is required/, 'Dies when pipeline is missing' );
};

# Test 5: execute_pipeline callback validation
subtest 'execute_pipeline callback validation' => sub {
    my $client   = FileServerSdk::Client->new();
    my $pipeline = FileServerSdk::SequentialPipeline->new();

    # Test webhook URL without callbacks
    eval { $client->execute_pipeline( $pipeline, 'http://example.com' ); };
    like(
        $@,
        qr/on_success callback is required/,
        'Dies when webhook_url provided without on_success callback'
    );
};

subtest 'execute_pipeline on_success callback required' => sub {
    my $client   = FileServerSdk::Client->new();
    my $pipeline = FileServerSdk::SequentialPipeline->new();

    eval {
        $client->execute_pipeline( $pipeline, 'http://example.com', undef,
            sub { } );
    };
    like(
        $@,
        qr/on_success callback is required/,
        'Dies when on_success is not a code reference'
    );
};

subtest 'execute_pipeline on_error callback required' => sub {
    my $client   = FileServerSdk::Client->new();
    my $pipeline = FileServerSdk::SequentialPipeline->new();

    eval {
        $client->execute_pipeline( $pipeline, 'http://example.com', sub { },
            undef );
    };
    like(
        $@,
        qr/on_error callback is required/,
        'Dies when on_error is not a code reference'
    );
};

# Test 6: handle_webhook validation
subtest 'handle_webhook validation' => sub {
    my $client = FileServerSdk::Client->new();

    # Mock CGI params
    local *CGI::param = sub {
        my $param = $_[0];
        return undef if !defined $param;
        return $param eq 'secret' ? 'invalid_secret' : undef;
    };

    my $result = $client->handle_webhook();
    is( $result, 0, 'handle_webhook returns 0 for invalid secret' );
};

# Test 7: handle_webhook missing parameters
subtest 'handle_webhook missing parameters' => sub {
    my $client = FileServerSdk::Client->new();

    local *CGI::param = sub {
        my $param = $_[0];
        return $ENV{PIPELINE_SHARED_SECRET} if $param eq 'secret';
        return 'test_pipeline_id'           if $param eq 'pipelineId';
        return undef;
    };

    my $result = $client->handle_webhook();
    is( $result, 0, 'handle_webhook returns 0 when status is missing' );
};

# Test 8: handle_webhook no callbacks
subtest 'handle_webhook no callbacks found' => sub {
    my $client = FileServerSdk::Client->new();

    local *CGI::param = sub {
        my $param = $_[0];
        return $ENV{PIPELINE_SHARED_SECRET} if $param eq 'secret';
        return 'unknown_pipeline_id'        if $param eq 'pipelineId';
        return 'completed'                  if $param eq 'status';
        return undef;
    };

    my $result = $client->handle_webhook();
    is( $result, 0, 'handle_webhook returns 0 when no callbacks found' );
};

# Test 9: Callback storage
subtest 'Callback storage in execute_pipeline' => sub {
    my $client = FileServerSdk::Client->new();

    # Check that callbacks hash is initialized
    ok( exists $client->{callbacks}, 'Callbacks hash initialized' );
    is( ref( $client->{callbacks} ), 'HASH', 'Callbacks is a hashref' );
};

# Test 10: Constructor with arguments
subtest 'Constructor with custom arguments' => sub {
    my $client = FileServerSdk::Client->new(
        custom_option => 'test_value',
        another_arg   => 42
    );

    isa_ok( $client, 'FileServerSdk::Client' );
    is( $client->{custom_option}, 'test_value', 'Custom argument stored' );
    is( $client->{another_arg},   42,           'Another argument stored' );
};

done_testing();
