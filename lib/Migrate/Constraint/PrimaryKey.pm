package Migrate::Constraint::PrimaryKey;

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun verb);

use Migrate::Util;

use parent qw(Migrate::Constraint);

sub new {
    my ($class, $table, $column, $options) = @_;
    my $data = $class->SUPER::new($options);
    $data->{table} = $table || die("Table name needed\n"),
    $data->{column} = $column || die("Column name needed\n"),
    return bless($data, $class);
}

sub primary_key { 'PRIMARY KEY' }
sub autoincrement { 'AUTOINCREMENT' }

sub autoincrements { $_[0]->{options}->{autoincrement} }
sub table { $_[0]->{table} }
sub column { $_[0]->{column} }

sub build_name { 'pk_'.$_[0]->table.'_'.$_[0]->column }

sub autoincrement_sql { $_[0]->autoincrement if $_[0]->autoincrements }

sub to_sql {
    my $self = shift;
    $self->_join_elems($self->SUPER::to_sql, $self->primary_key, $self->autoincrement_sql);
}

return 1;
