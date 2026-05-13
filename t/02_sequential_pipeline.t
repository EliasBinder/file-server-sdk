#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

require_ok('FileServerSdk::SequentialPipeline');
require_ok('FileServerSdk::Tasks::PdfMergerTask');
require_ok('FileServerSdk::ParallelPipeline');

# Test 1: SequentialPipeline constructor
subtest 'SequentialPipeline constructor' => sub {
    my $pipeline = FileServerSdk::SequentialPipeline->new();
    isa_ok( $pipeline, 'FileServerSdk::SequentialPipeline' );

    # Check if steps array is initialized
    my @steps = $pipeline->get_steps();
    is( scalar(@steps), 0, 'Steps array is empty initially' );
};

# Test 2: SequentialPipeline constructor with arguments
subtest 'SequentialPipeline constructor with arguments' => sub {
    my $pipeline = FileServerSdk::SequentialPipeline->new(
        name => 'test_pipeline',
        id   => '12345'
    );

    isa_ok( $pipeline, 'FileServerSdk::SequentialPipeline' );
    is( $pipeline->{name}, 'test_pipeline', 'Name argument stored' );
    is( $pipeline->{id},   '12345',         'ID argument stored' );
};

# Test 3: add_task_step validation
subtest 'add_task_step validation - missing step' => sub {
    my $pipeline = FileServerSdk::SequentialPipeline->new();

    eval { $pipeline->add_task_step(undef); };
    like( $@, qr/step is required/, 'Dies when step is undefined' );
};

# Test 4: add_task_step validation - no to_json method
subtest 'add_task_step validation - no to_json method' => sub {
    my $pipeline     = FileServerSdk::SequentialPipeline->new();
    my $invalid_step = {};

    eval { $pipeline->add_task_step($invalid_step); };
    like(
        $@,
qr/(step must have a to_json method|Can't call method "can" on unblessed reference)/,
        'Dies when step does not have to_json method'
    );
};

# Test 5: add_task_step with valid step
subtest 'add_task_step with valid step' => sub {
    my $pipeline = FileServerSdk::SequentialPipeline->new();
    my $task     = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'output.pdf'
    );

    my $result = $pipeline->add_task_step($task);

    is( $result, $pipeline, 'add_task_step returns $self for method chaining' );
    my @steps = $pipeline->get_steps();
    is( scalar(@steps), 1,     'Step was added' );
    is( $steps[0],      $task, 'Correct step was added' );
};

# Test 6: Method chaining
subtest 'Method chaining with add_task_step' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'output1.pdf'
    );
    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file2.pdf'],
        output_file => 'output2.pdf'
    );

    my $pipeline =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step($task1)
      ->add_task_step($task2);

    my @steps = $pipeline->get_steps();
    is( scalar(@steps), 2, 'Both steps added via method chaining' );
};

# Test 7: add_parallel_pipeline_step validation - missing pipeline
subtest 'add_parallel_pipeline_step validation - missing pipeline' => sub {
    my $pipeline = FileServerSdk::SequentialPipeline->new();

    eval { $pipeline->add_parallel_pipeline_step(undef); };
    like( $@, qr/pipeline is required/, 'Dies when pipeline is undefined' );
};

# Test 8: add_parallel_pipeline_step validation - no to_json method
subtest 'add_parallel_pipeline_step validation - no to_json method' => sub {
    my $pipeline         = FileServerSdk::SequentialPipeline->new();
    my $invalid_pipeline = { some => 'data' };

    eval { $pipeline->add_parallel_pipeline_step($invalid_pipeline); };
    like(
        $@,
qr/(pipeline must have a to_json method|Can't call method "can" on unblessed reference)/,
        'Dies when pipeline does not have to_json method'
    );
};

# Test 9: add_parallel_pipeline_step with valid pipeline
subtest 'add_parallel_pipeline_step with valid pipeline' => sub {
    my $seq_pipeline = FileServerSdk::SequentialPipeline->new();
    my $parallel     = FileServerSdk::ParallelPipeline->new();

    my $result = $seq_pipeline->add_parallel_pipeline_step($parallel);

    is( $result, $seq_pipeline,
        'add_parallel_pipeline_step returns $self for method chaining' );
    my @steps = $seq_pipeline->get_steps();
    is( scalar(@steps), 1, 'Parallel pipeline step was added' );
};

# Test 10: to_json with single task
subtest 'to_json with single task' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'output.pdf'
    );
    my $pipeline = FileServerSdk::SequentialPipeline->new();
    $pipeline->add_task_step($task);

    my $json = $pipeline->to_json();

    is( ref($json), 'HASH', 'to_json returns a hash reference' );
    ok( exists $json->{0}, 'Step 0 exists in hash' );
    is( ref( $json->{0} ), 'HASH', 'Step 0 is a hash reference' );
};

# Test 11: to_json with multiple tasks
subtest 'to_json with multiple tasks' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'output1.pdf'
    );
    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file2.pdf'],
        output_file => 'output2.pdf'
    );

    my $pipeline =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step($task1)
      ->add_task_step($task2);

    my $json = $pipeline->to_json();

    is( ref($json), 'HASH', 'to_json returns a hash reference' );
    ok( exists $json->{0}, 'Step 0 exists' );
    ok( exists $json->{1}, 'Step 1 exists' );
    is( $json->{1}->{type}, 'pdf_merger', 'Step 1 is correctly serialized' );
};

# Test 12: get_steps returns correct list
subtest 'get_steps returns correct list' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['a.pdf'],
        output_file => 'out_a.pdf'
    );
    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['b.pdf'],
        output_file => 'out_b.pdf'
    );

    my $pipeline = FileServerSdk::SequentialPipeline->new();
    $pipeline->add_task_step($task1);
    $pipeline->add_task_step($task2);

    my @steps = $pipeline->get_steps();

    is( scalar(@steps), 2,      'get_steps returns 2 items' );
    is( $steps[0],      $task1, 'First step is correct' );
    is( $steps[1],      $task2, 'Second step is correct' );
};

done_testing();
