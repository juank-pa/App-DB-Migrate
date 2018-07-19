package Migrate::Index;

use overload
    fallback => 1,
    '""' => \&to_sql;

sub new {
    my ($class, $table, $columns, $options) = @_;
    my $data = {
        table => $table || die("Table name is needed\n"),
        columns => ref($columns) eq 'ARRAY'? $columns : [$columns],
        options => $options // {}
    };
    die ("Column is needed\n") if !$columns;
    return bless($data, $class);
}

sub table { $_[0]->{table} }
sub columns { $_[0]->{columns} }
sub name { $_[0]->{options}->{name} }
sub order { $_[0]->{options}->{order} }
sub length { $_[0]->{options}->{length} }
sub uses { $_[0]->{options}->{using} }
sub is_unique { $_[0]->{options}->{unique} }
sub options { $_[0]->{options}->{options} }

sub unique { 'UNIQUE' }
sub asc { 'ASC' }
sub desc { 'DESC' }
sub using { 'USING' }

sub _column_list_name { join('_', @{$_[0]->columns}) }

sub _column_order {
    my ($self, $column) = @_;
    return '' unless $self->order && $self->order->{$column};
    return (lc($self->order->{$column}) eq 'asc'? $self->asc : $self->desc);
}

sub _column_length { '' }

sub _column_sql {
    my ($self, $column) = @_;
    return $self->_join_elements($column.$self->_column_length($column), $self->_column_order($column));
}

sub _columns_sql {
    my $self = shift;
    return join(',', map { $self->_column_sql($_) } @{$self->columns});
}

sub _using_sql { $_[0]->using.' '.$_[0]->uses if $_[0]->uses }

sub to_sql {
    my $self = shift;
    my $table = $self->table;
    my $qtable = Migrate::Util::identifier_name($table);
    my $unique = $self->is_unique && $self->unique;
    my $name = Migrate::Util::identifier_name($self->name // 'idx_'.$table.'_'.$self->_column_list_name);
    my $columns = $self->_columns_sql();
    my $using = $self->_using_sql;
    return $self->_join_elements('CREATE', $unique, 'INDEX', $name, 'ON', $qtable, "($columns)", $using, $self->options);
}

sub _join_elements { shift; join ' ', grep { $_ } @_; }

return 1;
