# Presigned URLs Guide

Presigned URLs allow web browsers to upload files directly to S3 without storing credentials in the browser. This guide explains how to generate and use presigned URLs.

## How Presigned URLs Work

1. **Client requests upload URLs**: Browser makes a request to your server
2. **Server generates presigned URLs**: Server uses the SDK to create secure URLs
3. **Browser uploads files directly**: Browser uploads to S3 using the presigned URLs
4. **Confirmation**: Server confirms successful uploads

## Generating Presigned URLs

### Basic Generation

```perl
use FileServerSdk::Client;
use CGI qw/:standard -utf8/;

my $client = FileServerSdk::Client->new();

my $urls = $client->handle_generate_presigned_urls(
    'my-bucket',
    {
        max_files => 5,
        min_files => 1,
        expires_in => 3600,  # 1 hour
    }
);

print header('application/json');
print JSON->new->encode($urls);
```

### With Content Type Restrictions

```perl
my $urls = $client->handle_generate_presigned_urls(
    'my-bucket',
    {
        max_files => 10,
        min_files => 1,
        expires_in => 3600,
        content_types => [
            { type => 'application/pdf', limit => 20 },      # 20 MB
            { type => 'image/jpeg', limit => 5 },            # 5 MB
            { type => 'image/png', limit => 5 },             # 5 MB
        ]
    }
);
```

## Presigned URL Response

The generated URLs have this structure:

```json
{
  "urls": [
    {
      "index": 0,
      "uuid": "a1b2c3d4-e5f6-4g7h-8i9j-0k1l2m3n4o5p",
      "url": "https://s3.primuss.de/my-bucket",
      "fields": {
        "key": "a1b2c3d4-e5f6-4g7h-8i9j-0k1l2m3n4o5p",
        "AWSAccessKeyId": "AKIAIOSFODNN7EXAMPLE",
        "policy": "eyJleHBpcmF0aW9uIjoiMjAyNC0wMS0xNVQxMjowMDowMFoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJteS1idWNrZXQifV19",
        "signature": "jZbwILvQgCzWkFfXjPb1p7LqDi8=",
        "Content-Type": "application/pdf"
      }
    }
  ],
  "timestamp": 1705329600,
  "success": true
}
```

## Browser-Side Implementation

### HTML File Upload Form

```html
<!DOCTYPE html>
<html>
<head>
    <title>File Upload</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/dropzone/5.9.2/dropzone.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/dropzone/5.9.2/dropzone.min.css">
</head>
<body>
    <h1>Upload Files</h1>
    <form id="uploadForm" class="dropzone"></form>

    <script>
        Dropzone.options.uploadForm = {
            url: '/api/upload',
            acceptedFiles: '.pdf,.jpg,.png',
            maxFilesize: 20,
            
            init: function() {
                var dz = this;
                
                // Before sending files, get presigned URLs
                this.on('addedfiles', function(files) {
                    getPresignedUrls(files, function(urls) {
                        uploadFilesToS3(urls, dz);
                    });
                });
            }
        };

        function getPresignedUrls(files, callback) {
            var fileData = files.map(function(file, index) {
                return {
                    index: index,
                    content_type: file.type,
                    size: file.size
                };
            });

            fetch('/api/presigned-urls', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    files: fileData,
                    action: 'generate_presigned_urls'
                })
            })
            .then(response => response.json())
            .then(data => callback(data.urls))
            .catch(error => console.error('Error:', error));
        }

        function uploadFilesToS3(urls, dz) {
            var files = dz.files;
            
            urls.forEach(function(urlData, index) {
                var file = files[index];
                var formData = new FormData();
                
                // Add policy fields
                Object.keys(urlData.fields).forEach(function(key) {
                    formData.append(key, urlData.fields[key]);
                });
                
                // Add file
                formData.append('file', file);
                
                // Upload to S3
                fetch(urlData.url, {
                    method: 'POST',
                    body: formData
                })
                .then(response => {
                    if (response.ok) {
                        dz.emit('success', file);
                    } else {
                        dz.emit('error', file);
                    }
                })
                .catch(error => {
                    console.error('Upload error:', error);
                    dz.emit('error', file);
                });
            });
        }
    </script>
</body>
</html>
```

### jQuery/AJAX Implementation

```javascript
function uploadFileWithPresignedUrl(file) {
    // Step 1: Request presigned URL
    $.ajax({
        url: '/api/presigned-urls',
        type: 'POST',
        contentType: 'application/json',
        data: JSON.stringify({
            files: [{
                content_type: file.type,
                size: file.size
            }],
            action: 'generate_presigned_urls'
        }),
        success: function(response) {
            var urlData = response.urls[0];
            
            // Step 2: Upload file to S3
            var formData = new FormData();
            
            // Add all required fields
            for (var key in urlData.fields) {
                formData.append(key, urlData.fields[key]);
            }
            
            // Add the file
            formData.append('file', file);
            
            // Upload to S3
            $.ajax({
                url: urlData.url,
                type: 'POST',
                data: formData,
                processData: false,
                contentType: false,
                success: function() {
                    alert('File uploaded successfully!');
                },
                error: function() {
                    alert('Upload failed');
                }
            });
        },
        error: function() {
            alert('Failed to get presigned URLs');
        }
    });
}
```

## Server-Side Implementation

### Express.js Handler

```javascript
const express = require('express');
const app = express();

app.post('/api/presigned-urls', (req, res) => {
    const files = req.body.files;
    
    // Call Perl script via exec or similar
    const { execSync } = require('child_process');
    
    const perlScript = `
        use FileServerSdk::Client;
        use JSON;
        
        my $client = FileServerSdk::Client->new();
        my $urls = $client->handle_generate_presigned_urls(
            'my-bucket',
            {
                max_files => 5,
                expires_in => 3600,
                content_types => [
                    { type => 'application/pdf', limit => 20 },
                    { type => 'image/jpeg', limit => 5 }
                ]
            }
        );
        
        print JSON->new->encode($urls);
    `;
    
    try {
        const result = execSync(`perl -e '${perlScript}'`);
        res.json(JSON.parse(result));
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.listen(3000);
```

### Perl/Catalyst Handler

```perl
package MyApp::Controller::Upload;
use Moose;
use namespace::autoclean;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

sub presigned_urls : Local : ActionClass('REST') {
    my ($self, $c) = @_;
}

sub presigned_urls_POST {
    my ($self, $c) = @_;
    my $client = FileServerSdk::Client->new();
    
    eval {
        my $urls = $client->handle_generate_presigned_urls(
            'my-bucket',
            {
                max_files => 10,
                min_files => 1,
                expires_in => 3600,
                content_types => [
                    { type => 'application/pdf', limit => 20 },
                    { type => 'image/jpeg', limit => 5 },
                    { type => 'image/png', limit => 5 }
                ]
            }
        );
        
        $c->stash(urls => $urls);
    };
    
    if ($@) {
        $c->res->status(500);
        $c->stash(error => $@);
    }
}

__PACKAGE__->meta->make_immutable;
1;
```

## Configuration Options

### Max and Min Files

```perl
$client->handle_generate_presigned_urls(
    'my-bucket',
    {
        max_files => 10,  # Maximum 10 files
        min_files => 1,   # Minimum 1 file
    }
);
```

### Expiration Time

```perl
# Expires in 1 hour (default)
$client->handle_generate_presigned_urls($bucket, { expires_in => 3600 });

# Expires in 30 minutes
$client->handle_generate_presigned_urls($bucket, { expires_in => 1800 });

# Expires in 24 hours
$client->handle_generate_presigned_urls($bucket, { expires_in => 86400 });
```

### Content Type Restrictions

```perl
$client->handle_generate_presigned_urls(
    'my-bucket',
    {
        content_types => [
            # Only PDFs up to 20MB
            { type => 'application/pdf', limit => 20 },
            
            # Only images up to 5MB
            { type => 'image/jpeg', limit => 5 },
            { type => 'image/png', limit => 5 },
            { type => 'image/gif', limit => 5 },
            
            # No limit specified
            { type => 'application/msword' }
        ]
    }
);
```

## Security Considerations

### 1. Validate File Uploads

```perl
my $client = FileServerSdk::Client->new();

# The SDK validates:
# - File count (min_files, max_files)
# - Content type (if specified)
# - File size (if limit specified)
# - Shared secret

# Additional validation can be done on the client side
```

### 2. Use HTTPS

Always use HTTPS when transferring presigned URLs:

```perl
# Good
my $webhook_url = 'https://your-app.com/api/presigned-urls';

# Bad
my $webhook_url = 'http://your-app.com/api/presigned-urls';
```

### 3. Short Expiration Times

Set short expiration times for presigned URLs:

```perl
# 1 hour expiration (good)
{ expires_in => 3600 }

# 24 hours expiration (less secure)
{ expires_in => 86400 }
```

### 4. Restrict Content Types

Always specify allowed content types:

```perl
# Good - only allow specific types
content_types => [
    { type => 'application/pdf', limit => 20 }
]

# Bad - allow any content type
# (no content_types specified)
```

## Error Handling

### Client-Side Error Handling

```javascript
function handleUploadError(error) {
    if (error.response) {
        // Server error response
        if (error.response.status === 413) {
            alert('File is too large');
        } else if (error.response.status === 415) {
            alert('File type not allowed');
        } else {
            alert('Upload failed: ' + error.response.data.error);
        }
    } else {
        // Network error
        alert('Network error during upload');
    }
}
```

### Server-Side Error Handling

```perl
eval {
    my $urls = $client->handle_generate_presigned_urls(
        'my-bucket',
        { max_files => 5 }
    );
};

if ($@) {
    if ($@ =~ /exceeds the maximum limit/) {
        # Too many files
    } elsif ($@ =~ /Content type .* is not allowed/) {
        # Invalid content type
    } elsif ($@ =~ /File size .* exceeds/) {
        # File too large
    }
    
    warn "Error: $@\n";
}
```

## Best Practices

1. **Set appropriate expiration times**: Balance security with usability
2. **Restrict content types**: Only allow necessary file types
3. **Set file size limits**: Prevent large uploads
4. **Use HTTPS**: Always use HTTPS in production
5. **Validate on both sides**: Validate on client and server
6. **Handle errors gracefully**: Provide useful error messages to users
7. **Log all uploads**: Track who uploaded what and when
8. **Clean up failed uploads**: Delete files that weren't fully processed

## Troubleshooting

### "Number of files exceeds the maximum limit"

The client requested more files than allowed:

```perl
# Check max_files configuration
{ max_files => 10 }

# Ensure client doesn't request more files
```

### "Content type is not allowed"

The file type is not in the allowed list:

```perl
# Check content_types configuration
content_types => [
    { type => 'application/pdf', limit => 20 }
]

# Client must upload only PDFs
```

### "File size exceeds the limit"

The file is larger than the specified limit:

```perl
# Check file size limits
{ type => 'image/jpeg', limit => 5 }  # 5 MB limit

# User must upload smaller files
```

### "Invalid secret"

The shared secret doesn't match:

```perl
# Ensure PIPELINE_SHARED_SECRET is set correctly
export PIPELINE_SHARED_SECRET="your_secret"
```
