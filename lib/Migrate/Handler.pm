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
    print("$table\n");
    $self->_add_indices($table);
}

sub _add_indices {
    my ($self, $table) = @_;
    my @indices = grep { $_->index } @{$table->columns};
    $self->add_index($table->name, $_->name, $self->_get_index_options($_)) for @indices;
}

sub add_index { shift; my $res = create('index', @_); print("$res\n"); $res }

sub _get_index_options { $_[1]->index if ref($_[1]->index) eq 'HASH' }

sub drop_table {
    my ($self, $table) = @_;
    $self->push_sql("DROP TABLE ".$self->table_name($table));
}

sub drop_index {
    my ($self, $table, $column) = @_;
    $self->push_sql("DROP INDEX ".$self->table_name("idx_${table}_${column}"));
}

return 1;
