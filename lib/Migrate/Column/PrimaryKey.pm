package Migrate::Column::PrimaryKey;

use strict;
use warnings;

use Migrate::Factory qw(create class);

use parent qw(Migrate::Column);

sub new {
    my ($class, $table, $options) = @_;
    $options ||= {};
    my $datatype = class('datatype')->is_valid_datatype($options->{type})?
        $options->{type} : $class->default_datatype;

    my $col = $class->SUPER::new($options->{column} || 'id', $datatype, $options);
    $col->{table} = $table || die("Table name needed\n");

    my $autoincrement = delete($options->{autoincrement});
    my $pk_options = {};
    $pk_options->{autoincrement} = 1 if $autoincrement && !!grep(/^$datatype$/, $class->autoincrement_types);
    $pk_options->{name} = delete($options->{constraint}) if $options->{constraint};

    $col->{pk} = create('Constraint::PrimaryKey', $col->table, $col->name, $pk_options);
    $col->add_constraint($col->{pk});
    return $col;
}

sub default_datatype { 'integer' }
sub autoincrement_types { qw(integer bigint) }

sub table { $_[0]->{table} }
sub autoincrements { $_[0]->primary_key_constraint->autoincrements }
sub primary_key_constraint { $_[0]->{pk} }

return 1;
