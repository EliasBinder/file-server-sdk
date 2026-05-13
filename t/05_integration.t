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
require_ok('FileServerSdk::ParallelPipeline');
require_ok('FileServerSdk::Tasks::PdfMergerTask');

# Test 1: Simple sequential pipeline with single task
subtest 'Simple sequential pipeline with single task' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['document.pdf'],
        output_file => 'merged.pdf'
    );

    my $pipeline =
      FileServerSdk::SequentialPipeline->new()->add_task_step($task);

    my $json = $pipeline->to_json();

    is( ref($json), 'HASH', 'Sequential pipeline to_json returns hash' );
    ok( exists $json->{0}, 'First step exists' );
    is( $json->{0}->{type}, 'pdf_merger', 'Task type is correct' );
};

# Test 2: Sequential pipeline with multiple tasks
subtest 'Sequential pipeline with multiple tasks' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'file1.pdf', 'file2.pdf' ],
        output_file => 'merged_1.pdf'
    );

    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'file3.pdf', 'file4.pdf' ],
        output_file => 'merged_2.pdf'
    );

    my $pipeline =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step($task1)
      ->add_task_step($task2);

    my @steps = $pipeline->get_steps();
    is( scalar(@steps), 2, 'Pipeline has 2 tasks' );

    my $json = $pipeline->to_json();
    is( ref($json), 'HASH', 'to_json returns hash reference' );
    ok( exists $json->{0}, 'Step 0 exists' );
    ok( exists $json->{1}, 'Step 1 exists' );
};

# Test 3: Parallel pipeline with sequential pipelines
subtest 'Parallel pipeline with sequential pipelines' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'a1.pdf', 'a2.pdf' ],
        output_file => 'a_merged.pdf'
    );

    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'b1.pdf', 'b2.pdf' ],
        output_file => 'b_merged.pdf'
    );

    my $seq1 = FileServerSdk::SequentialPipeline->new()->add_task_step($task1);

    my $seq2 = FileServerSdk::SequentialPipeline->new()->add_task_step($task2);

    my $parallel =
      FileServerSdk::ParallelPipeline->new()
      ->add_sequential_pipeline($seq1)
      ->add_sequential_pipeline($seq2);

    my @steps = $parallel->get_steps();
    is( scalar(@steps), 2, 'Parallel pipeline has 2 sequential pipelines' );

    my $json = $parallel->to_json();
    is( ref($json),     'ARRAY', 'Parallel to_json returns array' );
    is( scalar(@$json), 2,       'Array has 2 elements' );
};

# Test 4: Mixed sequential with parallel pipeline step
subtest 'Sequential pipeline with parallel pipeline step' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['doc1.pdf'],
        output_file => 'task1.pdf'
    );

    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['doc2.pdf'],
        output_file => 'task2.pdf'
    );

    my $task3 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['doc3.pdf'],
        output_file => 'task3.pdf'
    );

    my $seq1 =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step($task2)
      ->add_task_step($task3);

    my $parallel =
      FileServerSdk::ParallelPipeline->new()->add_sequential_pipeline($seq1);

    my $main_seq =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step($task1)
      ->add_parallel_pipeline_step($parallel);

    my @steps = $main_seq->get_steps();
    is( scalar(@steps), 2, 'Main sequential has task and parallel step' );
};

# Test 5: Complex nested structure
subtest 'Complex nested structure' => sub {
    my @tasks = ();
    for my $i ( 1 .. 3 ) {
        push @tasks,
          FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => [ "file_${i}_1.pdf", "file_${i}_2.pdf" ],
            output_file => "output_$i.pdf"
          );
    }

    my $seq1 =
      FileServerSdk::SequentialPipeline->new()->add_task_step( $tasks[0] );

    my $seq2 =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step( $tasks[1] )
      ->add_task_step( $tasks[2] );

    my $parallel =
      FileServerSdk::ParallelPipeline->new()
      ->add_sequential_pipeline($seq1)
      ->add_sequential_pipeline($seq2);

    my $json = $parallel->to_json();
    is( ref($json),     'ARRAY', 'Complex structure serializes correctly' );
    is( scalar(@$json), 2,       'Parallel contains 2 sequential pipelines' );
};

# Test 6: Client with pipeline
subtest 'Client initialization with pipeline' => sub {
    my $client = FileServerSdk::Client->new();

    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['test.pdf'],
        output_file => 'output.pdf'
    );

    my $pipeline =
      FileServerSdk::SequentialPipeline->new()->add_task_step($task);

    # Verify pipeline can be converted to JSON
    my $json = $pipeline->to_json();
    ok( defined $json, 'Pipeline JSON created successfully' );

    isa_ok( $client, 'FileServerSdk::Client', 'Client created' );
};

# Test 7: Method chaining across classes
subtest 'Method chaining across classes' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['a.pdf'],
        output_file => 'a_out.pdf'
    );

    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['b.pdf'],
        output_file => 'b_out.pdf'
    );

    # Method chaining should work
    my $pipeline =
      FileServerSdk::SequentialPipeline->new()
      ->add_task_step($task1)
      ->add_task_step($task2)
      ->add_task_step(
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['c.pdf'],
            output_file => 'c_out.pdf'
        )
      );

    my @steps = $pipeline->get_steps();
    is( scalar(@steps), 3, 'All tasks added via chaining' );
};

# Test 8: Empty structures
subtest 'Empty structures' => sub {
    my $empty_seq = FileServerSdk::SequentialPipeline->new();
    my $seq_json  = $empty_seq->to_json();
    is( ref($seq_json), 'HASH', 'Empty sequential pipeline returns hash' );

    my $empty_parallel = FileServerSdk::ParallelPipeline->new();
    my $parallel_json  = $empty_parallel->to_json();
    is( ref($parallel_json), 'ARRAY', 'Empty parallel pipeline returns array' );
    is( scalar(@$parallel_json), 0, 'Empty parallel pipeline is empty array' );
};

# Test 9: Deeply nested structure
subtest 'Deeply nested structure with multiple levels' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['deep1.pdf'],
        output_file => 'deep1_out.pdf'
    );

    my $seq1 = FileServerSdk::SequentialPipeline->new()->add_task_step($task1);

    my $parallel1 =
      FileServerSdk::ParallelPipeline->new()->add_sequential_pipeline($seq1);

    # Sequential containing parallel
    my $main_seq = FileServerSdk::SequentialPipeline->new()
      ->add_parallel_pipeline_step($parallel1);

    my @main_steps = $main_seq->get_steps();
    is( scalar(@main_steps), 1, 'Main sequential has parallel step' );

    my $main_json = $main_seq->to_json();
    ok( defined $main_json->{0}, 'Main sequential JSON created' );
};

# Test 10: Multiple parallel pipelines in sequence
subtest 'Multiple parallel pipelines in sequence' => sub {
    my $task1 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['task1.pdf'],
        output_file => 'task1_out.pdf'
    );

    my $task2 = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['task2.pdf'],
        output_file => 'task2_out.pdf'
    );

    my $seq1 = FileServerSdk::SequentialPipeline->new()->add_task_step($task1);

    my $parallel1 =
      FileServerSdk::ParallelPipeline->new()->add_sequential_pipeline($seq1);

    my $seq2 = FileServerSdk::SequentialPipeline->new()->add_task_step($task2);

    my $parallel2 =
      FileServerSdk::ParallelPipeline->new()->add_sequential_pipeline($seq2);

    my $main =
      FileServerSdk::SequentialPipeline->new()
      ->add_parallel_pipeline_step($parallel1)
      ->add_parallel_pipeline_step($parallel2);

    my @steps = $main->get_steps();
    is( scalar(@steps), 2, 'Main pipeline has 2 parallel steps' );
};

done_testing();
