#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

require_ok('FileServerSdk::Tasks::PdfMergerTask');

# Test 1: PdfMergerTask constructor
subtest 'PdfMergerTask constructor' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'file1.pdf', 'file2.pdf' ],
        output_file => 'output.pdf'
    );

    isa_ok( $task, 'FileServerSdk::Tasks::PdfMergerTask' );
    is( ref( $task->{input_files} ), 'ARRAY',
        'input_files is array reference' );
    is( $task->{output_file}, 'output.pdf', 'output_file stored correctly' );
};

# Test 2: Constructor validation - missing input_files
subtest 'Constructor validation - missing input_files' => sub {
    eval {
        FileServerSdk::Tasks::PdfMergerTask->new( output_file => 'output.pdf' );
    };
    like( $@, qr/input_files is required/, 'Dies when input_files is missing' );
};

# Test 3: Constructor validation - missing output_file
subtest 'Constructor validation - missing output_file' => sub {
    eval {
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => ['file1.pdf'] );
    };
    like( $@, qr/output_file is required/, 'Dies when output_file is missing' );
};

# Test 4: Constructor validation - input_files not array
subtest 'Constructor validation - input_files not array' => sub {
    eval {
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => 'single_file.pdf',
            output_file => 'output.pdf'
        );
    };
    like(
        $@,
        qr/input_files must be an array reference/,
        'Dies when input_files is not an array reference'
    );
};

# Test 5: Constructor validation - empty input_files array
subtest 'Constructor validation - empty input_files array' => sub {
    eval {
        FileServerSdk::Tasks::PdfMergerTask->new(
            input_files => [],
            output_file => 'output.pdf'
        );
    };
    like(
        $@,
        qr/input_files cannot be empty/,
        'Dies when input_files is empty'
    );
};

# Test 6: input_files() accessor
subtest 'input_files accessor' => sub {
    my @files = ( 'file1.pdf', 'file2.pdf', 'file3.pdf' );
    my $task  = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => \@files,
        output_file => 'output.pdf'
    );

    my $result = $task->input_files();

    is( ref($result),     'ARRAY', 'input_files() returns array reference' );
    is( scalar(@$result), 3, 'input_files() returns correct number of files' );
    is( $result->[0],     'file1.pdf', 'First file is correct' );
    is( $result->[1],     'file2.pdf', 'Second file is correct' );
    is( $result->[2],     'file3.pdf', 'Third file is correct' );
};

# Test 7: output_file() accessor
subtest 'output_file accessor' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['file1.pdf'],
        output_file => 'final_output.pdf'
    );

    my $result = $task->output_file();
    is( $result, 'final_output.pdf',
        'output_file() returns correct output file' );
};

# Test 8: to_json with single file
subtest 'to_json with single file' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => ['single.pdf'],
        output_file => 'output.pdf'
    );

    my $json = $task->to_json();

    is( ref($json),    'HASH',               'to_json returns hash reference' );
    is( $json->{type}, 'pdf_merger',         'Type is pdf_merger' );
    is( ref( $json->{inputFiles} ), 'ARRAY', 'inputFiles in JSON is array' );
    is( scalar( @{ $json->{inputFiles} } ), 1,  'inputFiles has one element' );
    is( $json->{inputFiles}->[0], 'single.pdf', 'File name is correct' );
    is( $json->{outputFile},      'output.pdf', 'outputFile is correct' );
};

# Test 9: to_json with multiple files
subtest 'to_json with multiple files' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'doc1.pdf', 'doc2.pdf', 'doc3.pdf' ],
        output_file => 'merged.pdf'
    );

    my $json = $task->to_json();

    is( $json->{type}, 'pdf_merger', 'Type is pdf_merger' );
    is( scalar( @{ $json->{inputFiles} } ), 3,
        'inputFiles has three elements' );
    is( $json->{inputFiles}->[0], 'doc1.pdf',   'First file correct' );
    is( $json->{inputFiles}->[1], 'doc2.pdf',   'Second file correct' );
    is( $json->{inputFiles}->[2], 'doc3.pdf',   'Third file correct' );
    is( $json->{outputFile},      'merged.pdf', 'outputFile is merged.pdf' );
};

# Test 10: to_json returns new reference each time
subtest 'to_json returns independent references' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => [ 'file1.pdf', 'file2.pdf' ],
        output_file => 'output.pdf'
    );

    my $json1 = $task->to_json();
    my $json2 = $task->to_json();

    # Verify both are valid
    is( $json1->{type}, 'pdf_merger', 'First call returns valid JSON' );
    is( $json2->{type}, 'pdf_merger', 'Second call returns valid JSON' );

    # Verify they have the same content
    is( scalar( @{ $json1->{inputFiles} } ), 2,
        'First call has correct files' );
    is( scalar( @{ $json2->{inputFiles} } ),
        2, 'Second call has correct files' );
};

# Test 11: Constructor with special characters in filenames
subtest 'Constructor with special characters in filenames' => sub {
    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files =>
          [ 'document-v1.0.pdf', 'file_with_spaces.pdf', 'file (copy).pdf' ],
        output_file => 'merged-final_output.pdf'
    );

    my $json = $task->to_json();

    is( scalar( @{ $json->{inputFiles} } ), 3, 'Handles special characters' );
    is( $json->{inputFiles}->[0],
        'document-v1.0.pdf', 'File with dash and version' );
    is( $json->{inputFiles}->[1],
        'file_with_spaces.pdf', 'File with underscores' );
    is( $json->{inputFiles}->[2], 'file (copy).pdf', 'File with parentheses' );
};

# Test 12: Large number of input files
subtest 'Large number of input files' => sub {
    my @files = map { "document_$_.pdf" } ( 1 .. 100 );

    my $task = FileServerSdk::Tasks::PdfMergerTask->new(
        input_files => \@files,
        output_file => 'merged_100.pdf'
    );

    my $json = $task->to_json();

    is( scalar( @{ $json->{inputFiles} } ), 100, 'Handles 100 input files' );
    is( $json->{inputFiles}->[0],  'document_1.pdf',   'First file correct' );
    is( $json->{inputFiles}->[99], 'document_100.pdf', 'Last file correct' );
};

done_testing();
