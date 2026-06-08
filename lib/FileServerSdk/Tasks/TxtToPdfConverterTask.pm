package FileServerSdk::Tasks::TxtToPdfConverterTask;
use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;

    die "input_file is required\n"  unless $args{input_file};
    die "output_file is required\n" unless $args{output_file};

    my $self = {};
    foreach my $key ( keys %args ) {
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

sub to_json {
    my ($self) = @_;
    return {
        type       => 'txt_to_pdf_converter',
        inputFile  => $self->input_file,
        outputFile => $self->output_file,
    };
}

sub get_files {
    my ($self) = @_;

    my @files = ( $self->output_file, $self->input_file );
    return @files;
}

1;
