package App::DB::Migrate::SQLite::Index;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Index);

sub rename { $_[0]->{options}->{name} = $_[1] }

sub remove_column {
    my ($self, $column) = @_;
    $self->{columns} = [ grep !/$column/, @{ $self->{columns} } ];
}

sub rename_column {
    my ($self, $from, $to) = @_;
    s/$from/$to/ for @{ $self->columns };
}

sub has_columns { scalar @{ $_[0]->columns } }

return 1;
