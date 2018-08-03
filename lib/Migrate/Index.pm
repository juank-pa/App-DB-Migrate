package Migrate::Index;

use parent qw(Migrate::SQLizable);

use Migrate::Factory qw(id);

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

sub name { $_[0]->identifier->name }
sub identifier {
    my $self = shift;
    $self->{qname} //= id(
        $self->{options}->{name} // 'idx_'.$self->table.'_'.$self->_column_list_name, 1
    );
}

sub table { $_[0]->{table} }
sub columns { $_[0]->{columns} }
sub order { $_[0]->{options}->{order} }
sub length { $_[0]->{options}->{length} }
sub uses { $_[0]->{options}->{using} }
sub is_unique { $_[0]->{options}->{unique} }
sub options { $_[0]->{options}->{options} }

sub unique { 'UNIQUE' }
sub asc { 'ASC' }
sub desc { 'DESC' }

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

sub dbspace { undef }

sub to_sql {
    my $self = shift;
    my $table = $self->table;
    my $qtable = $table;
    my $unique = $self->is_unique && $self->unique;
    my $name = $self->identifier;
    my $columns = $self->_columns_sql();
    my $using = undef;
    my $options = Migrate::Config::config->{add_options}? $self->options : undef;
    return $self->_join_elems('CREATE', $unique, 'INDEX', $name, 'ON', $qtable, "($columns)", $using, $self->dbspace, $options);
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

return 1;
