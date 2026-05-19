package FileServerSdk::ParallelPipeline;
use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;

    # Manually create and initialize the hash reference
    my $self = {};

    # Copy arguments into the hash
    foreach my $key ( keys %args ) {
        $self->{$key} = $args{$key};
    }

    # Initialize steps array
    $self->{steps} = [];

    # Manually bless the reference into the class
    bless $self, $class;

    return $self;
}

sub add_sequential_pipeline {
    my ( $self, $pipeline ) = @_;

    die "pipeline is required\n" unless defined $pipeline;
    die "pipeline must have a to_json method\n"
      unless $pipeline->can('to_json');

    push @{ $self->{steps} }, $pipeline;
    return $self;    # Allow method chaining
}

sub get_steps {
    my ($self) = @_;
    return @{ $self->{steps} };
}

sub to_json {
    my ($self) = @_;

    my @steps_json = map { $_->to_json() } @{ $self->{steps} };
    return \@steps_json;
}

sub get_files {
    my ($self) = @_;

    my @files;
    foreach my $step ( @{ $self->{steps} } ) {
        if ( $step->can('get_files') ) {
            push @files, $step->get_files();
        }
    }
    return @files;
}

1;
