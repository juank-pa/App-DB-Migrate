package Migrate::Constraint::ForeignKey;

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun);

use Migrate::Util;
use Migrate::Config;

use parent qw(Migrate::Constraint);

sub new {
    my ($class, $from_table, $to_table, $options) = @_;
    my $data = $class->SUPER::new($options);
    $data->{from_table} = $from_table || die("From table needed\n");
    $data->{to_table} = $to_table || die("To table needed\n");
    return bless($data, $class);
}

sub from_table { $_[0]->{from_table} }
sub to_table { $_[0]->{to_table} }

sub column { $_[0]->{options}->{column} || $_[0]->_get_column_name }
sub primary_key { $_[0]->{options}->{primary_key} || Migrate::Config::id($_[0]->to_table) }

sub build_name { 'fk_'.$_[0]->from_table.'_'.$_[0]->column }

sub delete_action { $_[0]->{options}->{on_delete} }
sub update_action { $_[0]->{options}->{on_update} }

sub valid_rules {
    {
        cascade => 'CASCADE',
        nullify => 'SET NULL',
        restrict => 'RESTRICT'
    }
}

sub references { 'REFERENCES' }
sub on_delete { 'ON DELETE' }
sub on_update { 'ON UPDATE' }

sub _get_column_name {
    my $self = shift;
    (my $to_table = $self->to_table) =~ s/_+/ /g;
    (my $singular = noun($to_table)->singular) =~ s/\s+/_/g;
    return $singular.'_id';
}

sub to_sql {
    my $self = shift;
    my $delete_rule = $self->valid_rules('delete')->{$self->delete_action // ''};
    my $update_rule = $self->valid_rules('update')->{$self->update_action // ''};
    my $on_delete = $delete_rule && $self->on_delete? $self->on_delete.' '.$delete_rule : undef;
    my $on_update = $update_rule && $self->on_update? $self->on_update.' '.$update_rule : undef;
    my @elems = $self->add_constraint($self->references, $self->to_table, '('.$self->primary_key.')', $on_delete, $on_update);
    return $self->_join_elems(@elems);
}

return 1;
