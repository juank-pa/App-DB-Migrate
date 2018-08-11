package Migrate::SQLite::Editor::Index;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Migrate::SQLite::Editor::Util qw(trim);
use Migrate::Factory qw(id);

sub new {
    my ($class, $name, $table, $columns, $options) = @_;
    return bless { name => $name, table => $table, columns => $columns, options => $options // {} }, $class;
}

sub rename { $_[0]->{name} = $_[1] }

sub table { shift->{table} }
sub name { shift->{name} }
sub columns { shift->{columns} }
sub unique { shift->options->{unique} }
sub options { shift->{options} }

sub to_sql {
    my $self = shift;
    my $columns = join ', ', (map { id($_) } @{ $self->columns });
    my $unique = $self->unique? 'UNIQUE ' : '';
    return "CREATE ${unique}INDEX ".id($self->{name}).' ON '.id($self->table)." ($columns)";
}

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
