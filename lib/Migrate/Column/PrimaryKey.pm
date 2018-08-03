package Migrate::Column::PrimaryKey;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Migrate::Factory qw(primary_key column class);
use Migrate::Config;

sub new {
    my ($class, $table, $column, $options) = @_;
    ($column, $options) = (undef, $column) if ref($column) eq 'HASH';
    $options ||= {};
    $table || die("Table name needed\n");
    my $datatype = class('datatype')->is_valid_datatype($options->{type})?
        $options->{type} : $class->default_datatype;

    my $col = column($column || Migrate::Config::id($table), $datatype, $options);

    my $autoincrement = $options->{autoincrement};
    my $pk_options = {};
    $pk_options->{autoincrement} = 1 if $autoincrement && !!grep(/^$datatype$/, $class->autoincrement_types);
    $pk_options->{name} = $options->{name} if $options->{name};

    $col->{pk} = primary_key($table, $col->name, $pk_options);
    $col->add_constraint($col->{pk});
    return bless { table => $table, column => $col }, $class;
}

sub default_datatype { 'integer' }
sub autoincrement_types { qw(integer bigint) }

# Delegates
sub name { $_[0]->{column}->name }
sub options { $_[0]->{column}->options }
sub datatype { $_[0]->{column}->datatype }
sub constraints { $_[0]->{column}->contraints }
sub index { $_[0]->{column}->index }
sub to_sql { $_[0]->{column}->to_sql }

sub table { $_[0]->{table} }
sub autoincrements { $_[0]->{column}->primary_key_constraint->autoincrements }
sub primary_key_constraint { $_[0]->{pk} }

return 1;
