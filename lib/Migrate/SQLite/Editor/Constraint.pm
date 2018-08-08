package Migrate::SQLite::Editor::Constraint;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Migrate::Factory qw(id);
use Migrate::SQLite::Editor::Util qw(unquote);

sub new {
    my ($class, $name, $type, @pred) = @_;
    $name = unquote($name);
    return bless { name => $name, type => $type, pred => [@pred] }, $class;
}

sub name { $_[0]->{name} }
sub type { $_[0]->{type} }
sub predicate { $_[0]->{pred} }
sub set_predicate { $_[0]->{pred} = $_[1] }

sub to_sql {
    my $self = shift;
    my $constraint = $self->name? 'CONSTRAINT '.id($self->name) : undef;
    return join ' ', grep { $_ } ($constraint, $self->{type}, @{ $self->{pred} });
}

return 1;
