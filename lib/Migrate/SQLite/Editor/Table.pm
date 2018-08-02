package Migrate::SQLite::Editor::Table;

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun verb);

use Migrate::SQLite::Editor::Index;
use Migrate::SQLite::Editor::Column;
use Migrate::SQLite::Editor::Util qw(get_id_re string_re name_re);
use Migrate::SQLite::Editor::Parser qw(parse_column);
use Migrate::Util;
use Migrate::Factory qw(create class);

use feature 'say';

sub new {
    my ($class, $prefix, $postfix, @columns) = @_;
    my $data = {
        prefix => $prefix,
        postfix => $postfix,
        columns => [@columns],
        changes => 0,
        added_columns => [],
        heavy => 0,
        renames => {}
    };
    return bless $data, $class;
}

sub columns { $_[0]->{columns} }
sub column_names { map { $_->name } @{ $_[0]->columns } }

sub _insert_column_names {
    my $self = shift;
    my @columns = map { $_->name } @{ $self->columns };
    my @added_columns = @{ $self->{added_columns} };
    return @columns unless scalar @added_columns;

    for my $col (@added_columns) {
        @columns = grep { $_ ne $col } @columns;
    }
    return map { $_->name } @columns;
}

sub rename {
    my $self = shift;
    my $new_name = shift;
    my $prev_name = $self->name;
    my $re = _name_re();
    $self->{prefix} =~ s/$re/$+{prefix}"$new_name"/;
    return qq{ALTER TABLE "$prev_name" RENAME TO "$new_name"};
}

sub _name_re {
    my $table_re = get_id_re('table');
    return qr/^(?<prefix>create\s+table\s+)(?:$table_re)/i;
}

sub name {
    my $self = shift;
    my $name_re = get_id_re('table');
    $self->{prefix} =~ /\s*create\s+table\s*$name_re/io;
    return $+{qtable} || $+{utable};
}

sub indexes { $_[0]->{indexes} }

sub add_raw_column {
    my ($self, $column_sql) = @_;
    my $table = $self->name;
    my $column_obj = parse_column($column_sql);
    push(@{ $self->{columns} }, $column_obj);
    push(@{ $self->{added_columns} }, $column_obj->name);
    return $self->set_changed(1, 1);
}

sub remove_columns {
    my ($self, @columns) = @_;
    my $prev_count = scalar(@{ $self->columns });
    foreach my $column (@columns) {
        $self->{columns} = [ $self->_remove_column($column) ];
        $self->{indexes} = [ $self->_remove_indexes($column) ];
    }
    my $new_count = scalar(@{ $self->columns });
    return $self->set_changed($new_count != $prev_count, 1);
}

sub set_changed {
    my ($self, $changed, $heavy, $from, $to) = @_;
    return $self unless $changed;

    $self->{heavy} ||= $heavy;
    $self->{changed} ||= $changed;
    $self->{changes}++;
    $self->{renames}->{$to} = $from if $from && $to;
    return $self;
}

sub add_foreign_key {
    my ($self, $to, $options) = @_;
    my $column_name = _get_reference_column($options, $to);
    my $column = $self->_column($column_name);
    return $self->set_changed($column->add_foreign_key($self->name, $to, $options), 1);
}

sub remove_foreign_key {
    my ($self, $to, $options) = @_;
    my $column_name = _get_reference_column($options, $to);
    my $column = $self->_column($column_name);
    return $self->set_changed($column->remove_foreign_key(), 0);
}

sub _get_reference_column {
    my $options = shift // {};
    my $table_name = shift || die('Need table name');
    return $options->{column} || noun($table_name)->singular.'_id'
}

sub rename_column {
    my ($self, $from, $to) = @_;
    my $column = $self->_column($from);
    $self->_rename_indexes($from, $to);
    return $self->set_changed($column->rename($to), 1, $from, $to);
}

sub _column {
    my ($self, $column) = @_;
    for (@{ $self->columns }) {
        return $_ if $_->name eq $column;
    }
}

sub change_column {
    my ($self, $column_name, $datatype, $options) = @_;
    ($datatype, $options) = (undef, $datatype) if ref($datatype) eq 'HASH';
    $self->change_column_null($column_name, $options->{null}) if exists($options->{null});
    $self->change_column_default($column_name, $options->{default}) if exists($options->{default});
    $self->_column($column_name)->change_datatype($datatype, $options) if $datatype;
    return $self->set_changed(0, 1);
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

sub _alter_table {
    my $self = shift;
    my $orig_table = $self->name;
    my $clone_table = "_$orig_table(clone)";

    $self->rename($clone_table);
    my $table_sql = $self->table_sql;
    my $rename_sql = $self->rename($orig_table);
    my $copy_sql = _copy_data_sql($orig_table, $clone_table, [ $self->_insert_column_names ], $self->{renames});
    my $drop_sql = qq{DROP TABLE "$orig_table"};

    return ($table_sql, $copy_sql, $drop_sql, $rename_sql, @{ $self->{indexes} });
}

sub _remove_indexes {
    my ($self, $column, $indexes) = @_;
    my @indexes = @{ $self->indexes };
    $_->remove_column($column) for @indexes;
    return grep { $_->has_columns } @indexes;
}

sub _rename_indexes {
    my ($self, $column, $new_column, $indexes) = @_;
    $_->rename_column($column, $new_column) for @{ $self->indexes };
}

sub _remove_column {
    my ($self, $column) = @_;
    return grep { $_->name ne $column } @{ $self->columns };
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

sub has_changed { $_[0]->{changed} }

sub table_sql { my $self = shift; ($self->{prefix}.join(',', @{ $self->{columns} }).$self->{postfix}) }

sub added_columns_count { scalar @{ $_[0]->{added_columns} } }

sub added_columns_only { my $added = $_[0]->added_columns_count; $added && $added == $_[0]->{changes} }

sub added_columns_sql {
    my $self = shift;
    my $table = $self->name;
    return map { qq{ALTER TABlE "$table" ADD COLUMN }.$_ } @{ $self->{added_columns} };
}

sub to_sql {
    my $self = shift;
    return $self->added_columns_sql if $self->added_columns_only;
    return $self->has_changed? $self->_alter_table() : $self->table_sql;
}

return 1;
