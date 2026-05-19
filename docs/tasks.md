# Tasks Guide

Tasks represent individual file processing operations. This guide covers working with existing tasks and creating custom tasks.

## Built-in Tasks

### PdfMergerTask

Merges multiple PDF files into a single output file.

#### Basic Usage

```perl
use FileServerSdk::Tasks::PdfMergerTask;

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => ['bucket/file1.pdf', 'bucket/file2.pdf'],
    output_file => 'bucket/merged.pdf'
);
```

#### Parameters

- `input_files` (required, array ref): List of S3 file paths to merge
- `output_file` (required, string): S3 path for the merged output file

#### Constraints

- At least 2 input files required
- All files must be PDFs
- Output file must have `.pdf` extension
- Files are merged in the order specified

#### Example: Merging Multiple Documents

```perl
use FileServerSdk::Client;
use FileServerSdk::SequentialPipeline;
use FileServerSdk::Tasks::PdfMergerTask;

my $client = FileServerSdk::Client->new();

my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => [
        'documents/cover.pdf',
        'documents/chapter1.pdf',
        'documents/chapter2.pdf',
        'documents/appendix.pdf'
    ],
    output_file => 'documents/complete.pdf'
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

my $pipeline_id = $client->execute_pipeline($pipeline);
print "Pipeline ID: $pipeline_id\n";
```

## Creating Custom Tasks

### Task Interface

All tasks must implement the following interface:

```perl
package FileServerSdk::Tasks::MyTask;

sub new {
    my ($class, %args) = @_;
    # Validate arguments
    # Create and return blessed object
}

sub to_json {
    my ($self) = @_;
    # Return hashref representing task
    # Must include 'type' and 'inputFiles'/'outputFile'
}

sub get_files {
    my ($self) = @_;
    # Return list of all files (input and output)
}
```

### Full Example: Image Converter Task

```perl
package FileServerSdk::Tasks::ImageConverterTask;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;

    # Validate required arguments
    die "input_file is required\n" unless $args{input_file};
    die "output_file is required\n" unless $args{output_file};
    die "format is required (jpg, png, gif, webp)\n" unless $args{format};

    # Validate format
    my %valid_formats = (jpg => 1, png => 1, gif => 1, webp => 1);
    die "Invalid format: $args{format}\n" 
        unless $valid_formats{$args{format}};

    my $self = {};
    foreach my $key (keys %args) {
        $self->{$key} = $args{$key};
    }

    bless $self, $class;
    return $self;
}

sub input_file {
    my ($self) = @_;
    return $self->{input_file};
}

sub output_file {
    my ($self) = @_;
    return $self->{output_file};
}

sub format {
    my ($self) = @_;
    return $self->{format};
}

sub to_json {
    my ($self) = @_;
    return {
        type       => 'image_converter',
        inputFile  => $self->input_file,
        outputFile => $self->output_file,
        format     => $self->format,
    };
}

sub get_files {
    my ($self) = @_;
    return ($self->output_file, $self->input_file);
}

1;
```

### Usage Example: Image Converter Task

```perl
use FileServerSdk::Tasks::ImageConverterTask;

my $task = FileServerSdk::Tasks::ImageConverterTask->new(
    input_file => 'images/photo.jpg',
    output_file => 'images/photo.png',
    format => 'png'
);

my $pipeline = FileServerSdk::SequentialPipeline->new()
    ->add_task_step($task);

my $pipeline_id = $client->execute_pipeline($pipeline);
```

## Task Structure

### JSON Serialization

Tasks are serialized to JSON for transmission to the pipeline server. The JSON structure should follow:

```json
{
  "type": "task_type_name",
  "inputFiles": ["file1", "file2"],
  "outputFile": "output",
  "otherParameters": "value"
}
```

### File Paths

File paths should be in the format: `bucket/key/to/file`

Examples:
- `my-bucket/documents/file.pdf`
- `uploads/2024/document.pdf`
- `bucket/folder/subfolder/file.pdf`

## Advanced Task Patterns

### Task with Optional Parameters

```perl
package FileServerSdk::Tasks::CompressionTask;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;

    die "input_file is required\n" unless $args{input_file};
    die "output_file is required\n" unless $args{output_file};

    # Optional parameters with defaults
    my $compression_level = $args{compression_level} || 6;  # 0-9
    my $algorithm = $args{algorithm} || 'zip';

    die "Compression level must be 0-9\n" 
        if $compression_level < 0 || $compression_level > 9;

    my $self = {
        input_file => $args{input_file},
        output_file => $args{output_file},
        compression_level => $compression_level,
        algorithm => $algorithm,
    };

    bless $self, $class;
    return $self;
}

sub to_json {
    my ($self) = @_;
    return {
        type => 'compression',
        inputFile => $self->{input_file},
        outputFile => $self->{output_file},
        compressionLevel => $self->{compression_level},
        algorithm => $self->{algorithm},
    };
}

sub get_files {
    my ($self) = @_;
    return ($self->{output_file}, $self->{input_file});
}

1;
```

### Task with Multiple Output Files

```perl
package FileServerSdk::Tasks::SplitTask;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;

    die "input_file is required\n" unless $args{input_file};
    die "output_files must be array ref\n" 
        unless $args{output_files} && ref($args{output_files}) eq 'ARRAY';
    die "Must have at least 2 output files\n" 
        unless @{$args{output_files}} >= 2;

    my $self = {};
    foreach my $key (keys %args) {
        $self->{$key} = $args{$key};
    }

    bless $self, $class;
    return $self;
}

sub to_json {
    my ($self) = @_;
    return {
        type => 'split',
        inputFile => $self->{input_file},
        outputFiles => $self->{output_files},
    };
}

sub get_files {
    my ($self) = @_;
    return ($self->{input_file}, @{$self->{output_files}});
}

1;
```

## Task Best Practices

### 1. Comprehensive Validation

```perl
sub new {
    my ($class, %args) = @_;

    # Check required fields
    die "input_files is required\n" unless $args{input_files};
    
    # Check types
    die "input_files must be array ref\n" 
        unless ref($args{input_files}) eq 'ARRAY';
    
    # Check constraints
    die "input_files cannot be empty\n" 
        unless @{$args{input_files}};

    # ... rest of initialization
}
```

### 2. Clear File References

```perl
# Always include full bucket/key paths
my $task = FileServerSdk::Tasks::PdfMergerTask->new(
    input_files => [
        'my-bucket/documents/file1.pdf',
        'my-bucket/documents/file2.pdf'
    ],
    output_file => 'my-bucket/output/merged.pdf'
);
```

### 3. Immutable Object Properties

```perl
sub input_files {
    my ($self) = @_;
    return $self->{input_files};  # Read-only
}

# Don't provide setters unless mutation is needed
```

### 4. Consistent JSON Format

```perl
# Use camelCase for JSON keys (matching server expectations)
sub to_json {
    my ($self) = @_;
    return {
        type => 'task_type',           # snake_case
        inputFiles => [...],            # camelCase
        outputFile => '...',            # camelCase
        myParameter => '...',           # camelCase
    };
}
```

### 5. Document Task Behavior

```perl
=head1 DESCRIPTION

CompressionTask compresses files using the specified algorithm.

=head1 PARAMETERS

=over 4

=item input_file (required)

The S3 path of the file to compress

=item output_file (required)

The S3 path for the compressed output

=item compression_level (optional)

Compression level 0-9. Default: 6

=item algorithm (optional)

Compression algorithm: zip, gzip, bzip2. Default: zip

=back

=cut
```

## Testing Custom Tasks

### Unit Test Example

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use FileServerSdk::Tasks::ImageConverterTask;

# Test basic creation
my $task = FileServerSdk::Tasks::ImageConverterTask->new(
    input_file => 'test.jpg',
    output_file => 'test.png',
    format => 'png'
);

ok($task, 'Task created');
is($task->format, 'png', 'Format set correctly');

# Test JSON serialization
my $json = $task->to_json();
is($json->{type}, 'image_converter', 'Task type correct');
is($json->{outputFile}, 'test.png', 'Output file correct');

# Test file tracking
my @files = $task->get_files();
ok(grep { /test\.png/ } @files, 'Output file tracked');
ok(grep { /test\.jpg/ } @files, 'Input file tracked');

# Test validation
eval {
    FileServerSdk::Tasks::ImageConverterTask->new(
        input_file => 'test.jpg',
        output_file => 'test.png',
        format => 'invalid'
    );
};
ok($@, 'Invalid format rejected');

done_testing();
```

## Task Execution Context

When a task is executed by the pipeline server:

1. Input files must exist in S3
2. Output files are created/overwritten
3. Task execution may be parallelized
4. File paths are resolved from the configured S3 host
5. All file operations use configured credentials

## Debugging Tasks

### Inspect Task JSON

```perl
use JSON;

my $task = FileServerSdk::Tasks::PdfMergerTask->new(...);
my $json = $task->to_json();
print JSON->new->pretty->encode($json);
```

### Verify File Tracking

```perl
my @files = $task->get_files();
foreach my $file (@files) {
    print "File: $file\n";
}
```

### Log Task Execution

```perl
my $pipeline_id = $client->execute_pipeline($pipeline);
warn "Executing task for pipeline: $pipeline_id\n";
warn "Files: " . join(", ", $pipeline->get_files()) . "\n";
```
