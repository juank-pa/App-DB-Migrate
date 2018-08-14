package Migrate::SQLite::Editor::Table;

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun verb);

use Migrate::SQLite::Editor::Parser qw(parse_column);
use Migrate::Factory qw(id column);

sub new {
    my ($class, $name, $postfix, @columns) = @_;
    my $data = {
        name => $name || die('Table name needed'),
        postfix => $postfix,
        columns => [@columns],
        added_columns => {},
        changed => 0,
        heavy => 0,
        renames => {},
        indexes => []
    };
    return bless $data, $class;
}

sub postfix { shift->{postfix} }

sub columns { $_[0]->{columns} }
sub column_names { map { $_->name } @{ $_[0]->columns } }

sub name { $_[0]->{name} }

sub set_indexes { $_[0]->{indexes} = [splice(@_, 1)] }
sub indexes { $_[0]->{indexes} }

sub rename {
    my $self = shift;
    my $new_name = shift || die('Invalid table name');
    $self->{name} = $new_name;
}

sub add_raw_column {
    my ($self, $column_sql) = @_;
    my $column_obj = parse_column($column_sql);
    push(@{ $self->{columns} }, $column_obj);
    $self->{added_columns}->{$column_obj->name} = 1;
    return $self->set_changed(1, 1);
}

sub remove_columns {
    my ($self, @columns) = @_;
    foreach my $column (@columns) {
        $self->{columns} = [ $self->_remove_column($column) ];
        $self->{indexes} = [ $self->_remove_indexes($column) ];
    }
    return $self->set_changed(1, 1);
}

sub set_changed {
    my ($self, $changed, $heavy, $from, $to) = @_;
    return unless $changed;

    $self->{changed} = $changed;
    $self->{heavy} ||= $heavy;
    $self->{renames}->{$to} = $from if $from && $to;
    return 1;
}

sub add_foreign_key {
    my ($self, $fk) = @_;
    my $column = $self->_column($fk->column);
    return $self->set_changed(($column->add_foreign_key($fk)), 9, 2, 3);
}

sub remove_foreign_key {
    my ($self, $fk) = @_;
    my $column = $self->_column_with_constraint_named($fk->name) || die('Column with foreign key not found');
    return $self->set_changed($column->remove_foreign_key(), 0);
}

sub _column_with_constraint_named {
    my $self = shift;
    my $name = shift;
    return (grep { $_->has_constraint_named($name) } @{ $self->columns })[0];
}

sub _get_reference_column {
    my $options = shift // {};
    my $table_name = shift || die('Need table name');
    return $options->{column} || noun($table_name)->singular.'_id'
}

sub rename_column {
    my ($self, $from, $to) = @_;
    my $column = $self->_column($from);
    $self->_rename_index_column($from, $to);
    return $self->set_changed($column->rename($to), 1, $from, $to);
}

sub _column_not_found {
    die ("Column $_[0] not found in table $_[1]");;
}

sub _column {
    my ($self, $column) = @_;
    my $index = $self->_column_index($column);
    _column_not_found($column, $self->name) if $index == -1;
    return $self->columns->[$index];
}

sub _column_index {
    my ($self, $column) = @_;
    for my $i (0 .. $#{ $self->columns }) {
        return $i if $self->columns->[$i]->name eq $column;
    }
    return -1;
}

sub change_column {
    my ($self, $column_name, $datatype, $options) = @_;
    my $index = $self->_column_index($column_name);
    _column_not_found($column_name, $self->name) if $index < 0;
    ($datatype, $options) = (1, $datatype) if ref($datatype) eq 'HASH';
    $self->{columns}->[$index] = parse_column(column($column_name, $datatype, $options));
    return $self->set_changed(1, 1);
}

sub change_column_default {
    my ($self, $column_name, $default) = @_;
    my $column = $self->_column($column_name);
    return $self->set_changed($column->change_default($default), defined $default);
}

sub change_column_null {
    my ($self, $column_name, $null) = @_;
    my $column = $self->_column($column_name);
    return $self->set_changed($column->change_null($null), !$null);
}

sub _remove_indexes {
    my ($self, $column, $indexes) = @_;
    my @indexes = @{ $self->indexes };
    $_->remove_column($column) for @indexes;
    return grep { $_->has_columns } @indexes;
}

sub _rename_index_column {
    my ($self, $column, $new_column) = @_;
    $_->rename_column($column, $new_column) for @{ $self->indexes };
}

sub _remove_column {
    my ($self, $column) = @_;
    _column_not_found($column, $self->name) unless $self->_has_column($column);
    return grep { $_->name ne $column } @{ $self->columns };
}

sub _has_column {
    my ($self, $column) = @_;
    return grep { $_->name eq $column } @{ $self->columns };
}

sub _copy_data_sql {
    my ($from, $to, $columns, $renames) = @_;
    my $columns_from = _column_list($columns, $renames);
    my $columns_to = _column_list($columns);
    return qq{INSERT INTO "$to" ($columns_to) SELECT $columns_from FROM "$from"};
}

sub _column_list {
    my ($columns, $renames) = @_;
    my $columns_to = join(',', map { $renames->{$_}? qq{"$renames->{$_}"} : qq{"$_"}  } @$columns);
}

sub _original_column_names {
    my $self = shift;
    my @columns = map { $_->name } @{ $self->columns };
    return @columns unless keys %{ $self->{added_columns} };
    return grep { !$self->{added_columns}->{$_} } @columns;
}

sub rename_sql {
    my ($class, $old_name, $new_name) = @_;
    return 'ALTER TABLE '.id($old_name).' RENAME TO '.id($new_name);
}

sub _alter_table {
    my $self = shift;
    my $orig_table = $self->name;
    my $clone_table = "_$orig_table(clone)";

    $self->rename($clone_table);
    my $table_sql = $self->_table_sql;
    $self->rename($orig_table);
    my $rename_sql = $self->rename_sql($clone_table, $orig_table);
    my $copy_sql = _copy_data_sql($orig_table, $clone_table, [ $self->_original_column_names ], $self->{renames});
    my $drop_sql = qq{DROP TABLE "$orig_table"};

    return ($table_sql, $copy_sql, $drop_sql, $rename_sql, @{ $self->{indexes} });
}

sub has_changed { $_[0]->{changed} }

sub _table_sql {
    my $self = shift;
    my $postfix = $self->postfix? ' '.$self->postfix : '';
    return 'CREATE TABLE '.id($self->{name}).' ('.join(',', @{ $self->{columns} }).')'.$postfix;
}

sub to_sql {
    my $self = shift;
    return $self->has_changed? $self->_alter_table() : $self->_table_sql;
}

return 1;
