package FileServerSdk::Tasks::DmsObjectSetterTask;
use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;

    die "college is required\n"    unless $args{college};
    die "input_file is required\n" unless $args{input_file};
    die "source_id is required\n"  unless $args{source_id};

    my $self = {};
    foreach my $key ( keys %args ) {
        $self->{$key} = $args{$key};
    }

    bless $self, $class;
    return $self;
}

sub college {
    my ($self) = @_;
    return $self->{college};
}

sub input_file {
    my ($self) = @_;
    return $self->{input_file};
}

sub repository_id {
    my ($self) = @_;
    return $self->{repository_id};
}

sub source_id {
    my ($self) = @_;
    return $self->{source_id};
}

sub category_id {
    my ($self) = @_;
    return $self->{category_id};
}

sub file_name {
    my ($self) = @_;
    return $self->{file_name};
}

## Example: [{"key": "abc", "values": ["value1", "value2"]}, {"key": "def", "values": ["value3"]}]
sub properties {
    my ($self) = @_;
    return $self->{properties};
}

sub dms_object_id {
    my ($self) = @_;
    return $self->{dms_object_id};
}

sub to_json {
    my ($self) = @_;
    return {
        type        => 'dms_object_setter',
        college     => $self->college,
        inputFile   => $self->input_file,
        sourceId    => $self->source_id,
        categoryId  => $self->category_id   || undef,
        fileName    => $self->file_name     || undef,
        properties  => $self->properties    || undef,
        dmsObjectId => $self->dms_object_id || undef,
    };
}

sub get_files {
    my ($self) = @_;

    my @files = ( $self->input_file );
    return @files;
}

1;
