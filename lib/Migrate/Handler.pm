package Migrate::Handler;

use strict;
use warnings;

use Migrate::Config;
use Migrate::Util;
use Migrate::Factory qw(create);
use Migrate::Dbh qw{get_dbh};
use DBI;

use feature 'switch';

our $instance;
my $driver;

sub new {
    bless { sql => [] }, shift;
}

sub push_sql { push @{$_[0]->{sql}}, $_[1] }

sub create_table {
    my ($self, $name, $options, $sub) = @_;
    ($sub, $options) = ($options, undef) if ref($options) eq 'CODE';
    my $table = create('table', $name, $options);

    $sub->($table);
    $self->push_sql($table);
    $self->_add_indices($table);
}

sub _add_indices {
    my ($self, $table) = @_;
    my @indices = grep { $_->index } @{$table->columns};
    $self->add_index($table->name, $_->name, $self->_get_index_options($_)) for @indices;
}

sub _get_index_options { $_[1]->index if ref($_[1]->index) eq 'HASH' }

sub add_column {
    my ($self, $table, $column, $datatype, $options) = @_;
    return $self->add_raw_column($table, create('column', $column, $datatype, $options));
}

sub add_reference {
    my ($self, $table, $ref_name, $options) = @_;
    return $self->add_raw_column($table, create('Column::References', $self->table_name, $ref_name, $options));
}

sub add_timestamps {
    my ($self, $table, $options) = @_;
    $self->add_raw_column($table, create('Column::Timestamp', 'updated_at', $options));
    return $self->add_raw_column($table, create('Column::Timestamp', 'created_at', $options));
}

sub add_raw_column {
    my ($self, $table, $column) = @_;
    $self->push_sql('ALTER TABLE '.Migrate::Util::identifier_name($table).' ADD COLUMN '.$column;
}

sub add_index { shift->push_sql(create('index', @_)) }

sub drop_table {
    my ($self, $table) = @_;
    $self->push_sql('DROP TABLE '.Migrate::Util::identifier_name($table));
}

sub remove_column {
    my ($self, $table, $column) = @_;
    $self->push_sql('ALTER TABLE '.Migrate::Util::identifier_name($table)." DROP COLUMN $column");
}

sub remove_columns {
    my ($self, $table, @columns) = @_;
    $self->remove_column($table, $_) for @columns;
}

sub remove_reference {
    my ($self, $table, $name, $options) = @_;
    my $id_name = (ref($options->{foreign_key}) eq 'HASH' && $options->{foreign_key}->{column}) || "${name}_id";
    $self->remove_colum($table, $id_name);
}

sub remove_timestamps { $_[0]->remove_columns($_[1], 'created_at', 'updated_at') }

sub remove_index {
    my ($self, $table, $column, $options) = @_;
    my $index = create('index', $table, $column, $options);
    my $index_name = $index->name;
    $self->push_sql('DROP INDEX '.Migrate::Util::identifier_name($name));
}

sub flush { }

sub rename_index;
sub rename_table;
sub rename_column;

sub add_foreign_key;
sub remove_foreign_key;

sub change_column;
sub change_column_default;
sub change_column_null;

sub create_join_table;

return 1;
