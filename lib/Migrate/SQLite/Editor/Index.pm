package Migrate::SQLite::Editor::Index;

use strict;
use warnings;

use Migrate::SQLite::Editor::Util qw(trim get_id_re string_re);

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql() };

sub new {
    my ($class, $sql) = @_;
    return bless _get_index_data($sql), $class;
}

sub _get_index_data {
    my $sql = shift;
    my $index_re = _index_name_re();
    my $table_re = get_id_re('table');
    $sql =~ /^create\s+(?<unique>unique\s+)?index\s+$index_re\s+on\s+$table_re\s+\((?<cols>.*)\)/i;
    my $data = {
        package => $+{uschema} || $+{qschema},
        name => $+{uindex} || $+{qindex},
        unique => $+{unique},
        table => $+{utable} || $+{qtable},
    };
    $data->{columns} = [ map { trim($_) } split(',', $+{cols}) ];
    return $data;
}

sub _index_name_re {
    my $schema_re = get_id_re('schema');
    my $name_re = get_id_re('index');
    return qr/(?:$schema_re\.)?(?:$name_re)/i;
}

sub rename {

}

sub to_sql {
    my $self = shift;
    my $columns = join ',', @{ $self->{columns} };
    my $unique = $self->{unique}? 'UNIQUE ' : '';
    qq{CREATE ${unique}INDEX "$self->{name}" ON ($columns)};
}

sub remove_column {
    my ($self, $column) = @_;
    $self->{columns} = [ grep !/^$column/, @{ $self->{columns} } ];
}

sub has_columns { scalar @{ $_[0]->{columns} } }

return 1;
