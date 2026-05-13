package FileServerSdk::SequentialPipeline;
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

sub add_task_step {
    my ( $self, $step ) = @_;

    die "step is required\n"                unless defined $step;
    die "step must have a to_json method\n" unless $step->can('to_json');

    push @{ $self->{steps} }, $step;
    return $self;    # Allow method chaining
}

sub add_parallel_pipeline_step {
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

    my %steps_hash;
    for my $i ( 0 .. $#steps_json ) {
        $steps_hash{$i} = $steps_json[$i];
    }
    return \%steps_hash;
}

1;
