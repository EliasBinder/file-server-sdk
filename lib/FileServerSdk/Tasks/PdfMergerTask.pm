package FileServerSdk::Tasks::PdfMergerTask;
use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;

    die "input_files is required\n" unless $args{input_files};
    die "output_file is required\n" unless $args{output_file};

    die "input_files must be an array reference\n"
      unless ref( $args{input_files} ) eq 'ARRAY';
    die "input_files cannot be empty\n" unless @{ $args{input_files} };

    my $self = {};
    foreach my $key ( keys %args ) {
        $self->{$key} = $args{$key};
    }

    bless $self, $class;
    return $self;
}

sub input_files {
    my ($self) = @_;
    return $self->{input_files};
}

sub output_file {
    my ($self) = @_;
    return $self->{output_file};
}

sub to_json {
    my ($self) = @_;
    return {
        type       => 'pdf_merger',
        inputFiles => $self->input_files,
        outputFile => $self->output_file,
    };
}

sub get_files {
    my ($self) = @_;

    my @files = ( $self->output_file, @{ $self->input_files } );
    return @files;
}

1;
