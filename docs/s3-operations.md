# S3 Operations Guide

The File Server SDK provides comprehensive S3 operations for file management. This guide covers uploading, downloading, deleting files, and managing metadata.

## Basic File Operations

### Upload a File

```perl
use FileServerSdk::Client;

my $client = FileServerSdk::Client->new();

# Read file from disk
open(my $fh, '<', 'path/to/file.pdf') or die "Cannot open: $!";
my $content = do { local $/; <$fh> };
close($fh);

# Upload to S3
$client->upload_file('my-bucket', 'documents/file.pdf', $content);

print "File uploaded successfully!\n";
```

### Download a File

```perl
my $client = FileServerSdk::Client->new();

# Download from S3
my $content = $client->download_file('my-bucket', 'documents/file.pdf');

# Save to disk
open(my $fh, '>', 'local_file.pdf') or die "Cannot write: $!";
print $fh $content;
close($fh);

print "File downloaded successfully!\n";
```

### Delete a File

```perl
my $client = FileServerSdk::Client->new();

$client->delete_file('my-bucket', 'documents/file.pdf');

print "File deleted successfully!\n";
```

## Metadata Management

### Get File Metadata

```perl
my $client = FileServerSdk::Client->new();

my $metadata = $client->get_metadata('my-bucket', 'documents/file.pdf');

# Metadata is a hashref
foreach my $key (keys %$metadata) {
    print "$key: $metadata->{$key}\n";
}
```

### Set File Metadata

```perl
my $client = FileServerSdk::Client->new();

my $metadata = {
    author => 'John Doe',
    category => 'reports',
    version => '1.0',
    date_created => '2024-01-15',
};

$client->set_metadata('my-bucket', 'documents/file.pdf', $metadata);

print "Metadata set successfully!\n";
```

### Update Metadata

```perl
my $client = FileServerSdk::Client->new();

# Get current metadata
my $metadata = $client->get_metadata('my-bucket', 'documents/file.pdf');

# Update specific fields
$metadata->{last_modified} = time();
$metadata->{status} = 'approved';

# Write back
$client->set_metadata('my-bucket', 'documents/file.pdf', $metadata);

print "Metadata updated!\n";
```

## File Organization

### Create Directory Structure

While S3 doesn't have real directories, you can organize files using path prefixes:

```perl
my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';

# Organize files by type and date
my @files = ('document1.pdf', 'document2.pdf', 'image.png');

foreach my $file (@files) {
    open(my $fh, '<', $file) or die "Cannot open: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    my $key = "uploads/2024/01/15/$file";
    $client->upload_file($bucket, $key, $content);
    print "Uploaded to: $key\n";
}
```

### List Files by Prefix

```perl
my $client = FileServerSdk::Client->new();

# Get all files in a "directory"
# Note: Direct listing is not provided by this SDK,
# but you can track files in your application

my @tracked_files = (
    'documents/2024/01/file1.pdf',
    'documents/2024/01/file2.pdf',
    'documents/2024/02/file3.pdf',
);

foreach my $file (@tracked_files) {
    my ($bucket, $key) = split('/', $file, 2);
    # Process file
}
```

## Batch Operations

### Batch Upload

```perl
use FileServerSdk::Client;
use File::Find;

my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';
my $local_dir = '/path/to/files';

# Find all files recursively
find(sub {
    return unless -f $_;
    
    my $local_path = $File::Find::name;
    my $rel_path = File::Spec->abs2rel($local_path, $local_dir);
    my $s3_key = "uploads/$rel_path";
    
    open(my $fh, '<', $local_path) or die "Cannot open: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    $client->upload_file($bucket, $s3_key, $content);
    print "Uploaded: $s3_key\n";
}, $local_dir);
```

### Batch Download

```perl
my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';

my @files = (
    'documents/report1.pdf',
    'documents/report2.pdf',
    'documents/appendix.pdf',
);

my $output_dir = '/path/to/output';

foreach my $file (@files) {
    my $content = $client->download_file($bucket, $file);
    
    my $filename = (split('/', $file))[-1];
    my $output_path = "$output_dir/$filename";
    
    open(my $fh, '>', $output_path) or die "Cannot write: $!";
    print $fh $content;
    close($fh);
    
    print "Downloaded: $output_path\n";
}
```

### Batch Delete

```perl
my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';

my @files_to_delete = (
    'old/file1.pdf',
    'old/file2.pdf',
    'old/file3.pdf',
);

foreach my $file (@files_to_delete) {
    eval {
        $client->delete_file($bucket, $file);
        print "Deleted: $file\n";
    };
    if ($@) {
        warn "Failed to delete $file: $@\n";
    }
}
```

## Error Handling

### Handling Upload Errors

```perl
use FileServerSdk::Client;

my $client = FileServerSdk::Client->new();

eval {
    $client->upload_file('my-bucket', 'documents/file.pdf', $content);
    print "File uploaded successfully!\n";
};

if ($@) {
    die "Upload failed: $@\n";
}
```

### Handling Download Errors

```perl
eval {
    my $content = $client->download_file('my-bucket', 'documents/file.pdf');
};

if ($@) {
    if ($@ =~ /404/) {
        print "File not found\n";
    } elsif ($@ =~ /403/) {
        print "Access denied\n";
    } else {
        die "Download failed: $@\n";
    }
}
```

### Validation Before Operations

```perl
sub validate_file_for_upload {
    my ($file_path) = @_;
    
    die "File does not exist: $file_path" unless -f $file_path;
    die "File is empty: $file_path" unless -s $file_path;
    die "File exceeds size limit (100MB): $file_path" 
        if -s $file_path > 100 * 1024 * 1024;
    
    return 1;
}

# Usage
eval {
    validate_file_for_upload('path/to/file.pdf');
    
    open(my $fh, '<', 'path/to/file.pdf') or die "Cannot open: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    $client->upload_file('my-bucket', 'documents/file.pdf', $content);
};

if ($@) {
    warn "Validation or upload failed: $@\n";
}
```

## Performance Considerations

### Large File Handling

For very large files, consider streaming or chunking:

```perl
# For large files, read in chunks to minimize memory usage
sub read_file_chunked {
    my ($file_path, $chunk_size) = @_;
    $chunk_size ||= 1024 * 1024;  # 1MB default
    
    open(my $fh, '<', $file_path) or die "Cannot open: $!";
    
    my $content = '';
    while (my $bytes = read($fh, my $chunk, $chunk_size)) {
        $content .= $chunk;
        last unless $bytes == $chunk_size;
    }
    
    close($fh);
    return $content;
}
```

### Concurrent Operations

```perl
use Parallel::ForkManager;

my $client = FileServerSdk::Client->new();
my $pm = Parallel::ForkManager->new(4);  # 4 parallel processes

foreach my $file (@files) {
    $pm->start and next;
    
    eval {
        # Each child process gets its own client
        my $file_content = $client->download_file($bucket, $file);
        # Process file
    };
    
    warn "Error processing $file: $@" if $@;
    
    $pm->finish;
}

$pm->wait_all_children;
```

## Advanced Patterns

### File Versioning

```perl
my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';

sub upload_versioned_file {
    my ($base_key, $content) = @_;
    
    my $timestamp = time();
    my $versioned_key = "$base_key.$timestamp";
    
    $client->upload_file($bucket, $versioned_key, $content);
    
    # Update metadata to track current version
    my $metadata = {
        current_version => $versioned_key,
        timestamp => $timestamp,
    };
    
    $client->set_metadata($bucket, $base_key, $metadata);
    
    return $versioned_key;
}

# Usage
my $version = upload_versioned_file('documents/report.pdf', $content);
print "Uploaded as: $version\n";
```

### File Tagging and Categorization

```perl
my $client = FileServerSdk::Client->new();

sub tag_file {
    my ($bucket, $key, @tags) = @_;
    
    my $metadata = $client->get_metadata($bucket, $key);
    $metadata->{tags} = \@tags;
    
    $client->set_metadata($bucket, $key, $metadata);
}

sub categorize_file {
    my ($bucket, $key, $category) = @_;
    
    my $metadata = $client->get_metadata($bucket, $key);
    $metadata->{category} = $category;
    
    $client->set_metadata($bucket, $key, $metadata);
}

# Usage
tag_file($bucket, 'documents/report.pdf', 'report', 'quarterly', '2024');
categorize_file($bucket, 'documents/report.pdf', 'financial');
```

### Cleanup Pipeline Files

```perl
my $client = FileServerSdk::Client->new();
my $bucket = 'my-bucket';

# Clean up old files
my @old_files = (
    'temp/cache1.tmp',
    'temp/cache2.tmp',
    'temp/cache3.tmp',
);

foreach my $file (@old_files) {
    eval {
        $client->delete_file($bucket, $file);
        print "Cleaned up: $file\n";
    };
    if ($@) {
        warn "Failed to cleanup $file: $@\n";
    }
}

# Or use pipeline cleanup
$client->cleanup_pipeline($pipeline);
```

## Best Practices

1. **Always handle errors**: Use eval/die or try-catch patterns
2. **Validate inputs**: Check file existence and permissions before upload
3. **Use meaningful paths**: Organize files with clear, descriptive paths
4. **Track files**: Use metadata and logging to track file operations
5. **Clean up resources**: Delete temporary files when no longer needed
6. **Use appropriate bucket names**: Keep buckets organized and meaningful
7. **Set metadata**: Store relevant metadata for easy file discovery and management
