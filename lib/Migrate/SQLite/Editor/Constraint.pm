package Migrate::SQLite::Editor::Constraint;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

sub new {
    my ($class, $name, $type, @pred) = @_;
    return bless { name => $name, type => $type, pred => [@pred] }, $class;
}

sub type { $_[0]->{type} }
sub predicate { $_[0]->{pred} }
sub set_predicate { $_[0]->{pred} = $_[1] }

sub to_sql {
    my $self = shift;
    my $constraint = $self->{name}? "CONSTRAINT $self->{name}" : undef;
    return join ' ', grep { $_ } ($constraint, $self->{type}, @{ $self->{pred} });
}

return 1;
