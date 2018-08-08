package Migrate::SQLite::Editor::Index;

use strict;
use warnings;

use Migrate::SQLite::Editor::Util qw(trim get_id_re string_re);

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql() };

sub new {
    my ($class, $name, $table, $columns, $options) = @_;
    return bless { name => $name, table => $table, columns => $columns, options => $options // {} }, $class;
}

sub rename { $_[0]->{name} = $_[1] }

sub to_sql {
    my $self = shift;
    my $columns = join ',', @{ $self->{columns} };
    my $table = $self->{table};
    my $unique = $self->{unique}? 'UNIQUE ' : '';
    qq{CREATE ${unique}INDEX "$self->{name}" ON "$table" ($columns)};
}

sub remove_column {
    my ($self, $column) = @_;
    $self->{columns} = [ grep !/^$column/, @{ $self->{columns} } ];
}

sub rename_column {
    my ($self, $from, $to) = @_;
    map { s/\b$from\b/$to/ } @{ $self->{columns} };
}

sub has_columns { scalar @{ $_[0]->{columns} } }

return 1;
