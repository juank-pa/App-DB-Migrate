package Migrate::Handler;

use strict;
use warnings;

use Migrate::Config;
use Migrate::Util;
use Migrate::Factory qw(create);
use Migrate::Dbh qw{get_dbh};
use DBI;

use feature 'say';

our $instance;
my $driver;

# TODO:
# * Add support to create join_tables

sub new {
    bless { sql => [] }, shift;
}

sub execute {
    my $self = shift;
    my @sqls = @_;
    my $dbh = get_dbh();
    for my $sql (@sqls) {
        my $sth = $dbh->prepare($sql) or die("$DBI::errstr\n$sql");
        $sth->execute() or die("$DBI::errstr\n$sql");
        say($sql);
    }
}

sub create_table {
    my ($self, $name, $options, $sub) = @_;
    ($sub, $options) = ($options, undef) if ref($options) eq 'CODE';
    my $table = create('table', $name, $options);

    $sub->($table);
    $self->execute($table);

    my @indexes = grep { $_->index } @{$table->columns};
    $self->_add_indexes($table->name, @indexes);
}

sub _add_indexes {
    my ($self, $table, @indexes) = @_;
    $self->add_index($table, $_->name, $self->_get_index_options($_)) for @indexes;
}

sub _get_index_options { $_[1]->index if ref($_[1]->index) eq 'HASH' }

sub add_column {
    my ($self, $table, $column, $datatype, $options) = @_;
    return $self->add_raw_column($table, create('column', $column, $datatype, $options));
}

sub add_reference {
    my ($self, $table, $ref_name, $options) = @_;
    return $self->add_raw_column($table, create('Column::References', $table, $ref_name, $options));
}

sub add_timestamps {
    my ($self, $table, $options) = @_;
    $self->add_raw_column($table, create('Column::Timestamp', 'updated_at', $options));
    return $self->add_raw_column($table, create('Column::Timestamp', 'created_at', $options));
}

sub add_raw_column {
    my ($self, $table, $column) = @_;
    $self->execute('ALTER TABLE '.create('identifier', $table, 1).' ADD '.$column);
}

sub add_index { shift->execute(create('index', @_)) }

sub drop_table {
    my ($self, $table) = @_;
    $self->execute('DROP TABLE '.create('identifier', $table, 1));
}

sub remove_column {
    my ($self, $table, $column) = @_;
    $self->execute('ALTER TABLE '.create('identifier', $table, 1)." DROP $column");
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
    $self->execute('DROP INDEX '.create('identifier', $index_name, 1));
}

sub irreversible {
    die("Migration is irreversible!");
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
