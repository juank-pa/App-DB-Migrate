package App::DB::Migrate::SQLite::Editor::Constraint;

use strict;
use warnings;

use parent qw(App::DB::Migrate::SQLizable);

use App::DB::Migrate::Factory qw(id);
use App::DB::Migrate::SQLite::Editor::Util qw(unquote);

sub new {
    my ($class, $name, $type, @pred) = @_;
    my $data = {
        name => $name,
        type => uc($type // die('Constraint type is needed')),
        pred => [@pred]
    };
    return bless($data, $class);
}

sub name { shift->{name} }
sub type { shift->{type} }
sub predicate { shift->{pred} }
sub set_predicate { $_[0]->{pred} = [splice(@_, 1)] }

sub to_sql {
    my $self = shift;
    my $constraint = $self->name? 'CONSTRAINT '.id($self->name) : undef;
    return join ' ', grep { $_ } ($constraint, $self->{type}, @{ $self->{pred} });
}

return 1;
