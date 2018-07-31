package Migrate::Index;

use overload
    fallback => 1,
    '""' => \&to_sql;

# TODO:
# * Revisit using (not supported everywhere, and position)

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
sub name { $_[0]->{options}->{name} // 'idx_'.$_[0]->table.'_'.$_[0]->_column_list_name }
sub order { $_[0]->{options}->{order} }
sub length { $_[0]->{options}->{length} }
sub uses { $_[0]->{options}->{using} }
sub is_unique { $_[0]->{options}->{unique} }
sub options { $_[0]->{options}->{options} }

sub unique { 'UNIQUE' }
sub asc { 'ASC' }
sub desc { 'DESC' }
#sub using { 'USING' }

sub _column_list_name { join('_', @{$_[0]->columns}) }

sub _column_order {
    my ($self, $column) = @_;
    my $order = ref($self->order) eq 'HASH'? $self->order : { $column => $self->order };
    return '' unless $order->{$column};
    return (lc($order->{$column}) eq 'asc'? $self->asc : $self->desc);
}

sub _column_length { '' }

sub _column_sql {
    my ($self, $column) = @_;
    return $self->_join_elems($column.$self->_column_length($column), $self->_column_order($column));
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
    my $name = Migrate::Util::identifier_name($self->name);
    my $columns = $self->_columns_sql();
    my $using = undef;
    return $self->_join_elems('CREATE', $unique, 'INDEX', $name, 'ON', $qtable, "($columns)", $using, $self->options);
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

return 1;
