#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

require_ok('FileServerSdk::ParallelPipeline');
require_ok('FileServerSdk::SequentialPipeline');
require_ok('FileServerSdk::Tasks::PdfMergerTask');

# Test 1: ParallelPipeline constructor
subtest 'ParallelPipeline constructor' => sub {
    my $pipeline = FileServerSdk::ParallelPipeline->new();
    isa_ok( $pipeline, 'FileServerSdk::ParallelPipeline' );

    # Check if steps array is initialized
    my @steps = $pipeline->get_steps();
    is( scalar(@steps), 0, 'Steps array is empty initially' );
};

# Test 2: ParallelPipeline constructor with arguments
subtest 'ParallelPipeline constructor with arguments' => sub {
    my $pipeline = FileServerSdk::ParallelPipeline->new(
        name => 'parallel_test',
        id   => 'parallel_123'
    );

    isa_ok( $pipeline, 'FileServerSdk::ParallelPipeline' );
    is( $pipeline->{name}, 'parallel_test', 'Name argument stored' );
    is( $pipeline->{id},   'parallel_123',  'ID argument stored' );
};

# Test 3: add_sequential_pipeline validation - missing pipeline
subtest 'add_sequential_pipeline validation - missing pipeline' => sub {
    my $parallel = FileServerSdk::ParallelPipeline->new();

    eval { $parallel->add_sequential_pipeline(undef); };
    like( $@, qr/pipeline is required/, 'Dies when pipeline is undefined' );
};

# Test 4: add_sequential_pipeline validation - no to_json method
subtest 'add_sequential_pipeline validation - no to_json method' => sub {
    my $parallel         = FileServerSdk::ParallelPipeline->new();
    my $invalid_pipeline = { some => 'data' };

    eval { $parallel->add_sequential_pipeline($invalid_pipeline); };
    like(
        $@,
qr/(pipeline must have a to_json method|Can't call method "can" on unblessed reference)/,
        'Dies when pipeline does not have to_json method'
    );
};

# Test 5: add_sequential_pipeline with valid pipeline
subtest 'add_sequential_pipeline with valid sequential pipeline' => sub {
    my $parallel = FileServerSdk::ParallelPipeline->new();
    my $seq      = FileServerSdk::SequentialPipeline->new();

    my $result = $parallel->add_sequential_pipeline($seq);

    is( $result, $parallel,
        'add_sequential_pipeline returns $self for method chaining' );
    my @steps = $parallel->get_steps();
    is( scalar(@steps), 1,    'Sequential pipeline was added' );
    is( $steps[0],      $seq, 'Correct sequential pipeline was added' );
};

# Test 6: Method chaining
subtest 'Method chaining with add_sequential_pipeline' => sub {
    my $seq1 = FileServerSdk::SequentialPipeline->new();
    my $seq2 = FileServerSdk::SequentialPipeline->new();

    my $parallel =
      FileServerSdk::ParallelPipeline->new()
      ->add_sequential_pipeline($seq1)
      ->add_sequential_pipeline($seq2);

    my @steps = $parallel->get_steps();
    is( scalar(@steps), 2,
        'Both sequential pipelines added via method chaining' );
    is( $steps[0], $seq1, 'First sequential pipeline added correctly' );
    is( $steps[1], $seq2, 'Second sequential pipeline added correctly' );
};

# Test 7: to_json with single sequential pipeline
subtest 'to_json with single sequential pipeline' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'output.pdf'
    );
    my $seq = FileServerSdk::SequentialPipeline->new()->add_task_step($task);

    my $parallel =
      FileServerSdk::ParallelPipeline->new()->add_sequential_pipeline($seq);

    my $json = $parallel->to_json();

    is( ref($json),        'ARRAY', 'to_json returns an array reference' );
    is( scalar(@$json),    1,       'Array contains one element' );
    is( ref( $json->[0] ), 'HASH',  'First element is a hash reference' );
};

# Test 8: to_json with multiple sequential pipelines
subtest 'to_json with multiple sequential pipelines' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'output1.pdf'
    );
    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file2.pdf'],
        output_file => 'output2.pdf'
    );

    my $seq1 = FileServerSdk::SequentialPipeline->new()->add_task_step($task1);
    my $seq2 = FileServerSdk::SequentialPipeline->new()->add_task_step($task2);

    my $parallel =
      FileServerSdk::ParallelPipeline->new()
      ->add_sequential_pipeline($seq1)
      ->add_sequential_pipeline($seq2);

    my $json = $parallel->to_json();

    is( ref($json),     'ARRAY', 'to_json returns an array reference' );
    is( scalar(@$json), 2,       'Array contains two elements' );
};

# Test 9: get_steps with multiple pipelines
subtest 'get_steps returns correct list' => sub {
    my $seq1 = FileServerSdk::SequentialPipeline->new();
    my $seq2 = FileServerSdk::SequentialPipeline->new();
    my $seq3 = FileServerSdk::SequentialPipeline->new();

    my $parallel = FileServerSdk::ParallelPipeline->new();
    $parallel->add_sequential_pipeline($seq1);
    $parallel->add_sequential_pipeline($seq2);
    $parallel->add_sequential_pipeline($seq3);

    my @steps = $parallel->get_steps();

    is( scalar(@steps), 3,     'get_steps returns 3 items' );
    is( $steps[0],      $seq1, 'First step is correct' );
    is( $steps[1],      $seq2, 'Second step is correct' );
    is( $steps[2],      $seq3, 'Third step is correct' );
};

# Test 10: Complex structure - parallel with multiple sequential pipelines containing tasks
subtest 'Complex parallel-sequential-task structure' => sub {
    my $task1a = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'file1a.pdf', 'file1b.pdf' ],
        output_file => 'output1.pdf'
    );
    my $task2a = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file2a.pdf'],
        output_file => 'output2.pdf'
    );

    my $seq1 = FileServerSdk::SequentialPipeline->new()->add_task_step($task1a);
    my $seq2 = FileServerSdk::SequentialPipeline->new()->add_task_step($task2a);

    my $parallel =
      FileServerSdk::ParallelPipeline->new()
      ->add_sequential_pipeline($seq1)
      ->add_sequential_pipeline($seq2);

    my @steps = $parallel->get_steps();
    is( scalar(@steps), 2, 'Parallel pipeline has 2 sequential pipelines' );

    my @seq1_steps = $seq1->get_steps();
    is( scalar(@seq1_steps), 1, 'First sequential pipeline has 1 task' );

    my @seq2_steps = $seq2->get_steps();
    is( scalar(@seq2_steps), 1, 'Second sequential pipeline has 1 task' );
};

# Test 11: Empty parallel pipeline to_json
subtest 'Empty parallel pipeline to_json' => sub {
    my $parallel = FileServerSdk::ParallelPipeline->new();
    my $json     = $parallel->to_json();

    is( ref($json), 'ARRAY', 'Empty parallel to_json returns array reference' );
    is( scalar(@$json), 0,   'Empty parallel returns empty array' );
};

done_testing();
