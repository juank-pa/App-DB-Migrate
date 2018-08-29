package App::DB::Migrate::Column::PrimaryKey;

use strict;
use warnings;

use parent qw(App::DB::Migrate::SQLizable);

use App::DB::Migrate::Factory qw(primary_key column);
use App::DB::Migrate::Config;

sub new {
    my ($class, $table, $column, $options) = @_;
    $table || die('Table name needed');
    ($column, $options) = (undef, $column) if ref($column) eq 'HASH';
    $options ||= {};

    my $datatype = $options->{type} || $class->default_datatype;
    $column ||= App::DB::Migrate::Config::id($table);

    my $col = column($column, $datatype, $options);
    my $pk = $class->_get_pk($table, $column, $datatype, $options);
    $col->add_constraint($pk);
    return bless { column => $col, pk => $pk }, $class;
}

sub _get_pk {
    my ($class, $table, $column, $datatype, $options) = @_;
    my $autoincrement = $options->{autoincrement};
    my $pk_options = {};
    $pk_options->{autoincrement} = 1 if $autoincrement && !!grep(/^$datatype$/, $class->autoincrement_types);
    $pk_options->{name} = $options->{name} if $options->{name};

    return primary_key($table, $column, $pk_options);
}

sub default_datatype { 'integer' }
sub autoincrement_types { qw(integer bigint) }

# Delegates
sub name { $_[0]->{column}->name }
sub options { $_[0]->{column}->options }
sub type { $_[0]->{column}->type }
sub constraints { $_[0]->{column}->constraints }
sub index { $_[0]->{column}->index }
sub to_sql { $_[0]->{column}->to_sql }

sub autoincrements { $_[0]->primary_key_constraint->autoincrements }
sub primary_key_constraint { $_[0]->{pk} }

return 1;
