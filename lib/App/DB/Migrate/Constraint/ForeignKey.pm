package App::DB::Migrate::Constraint::ForeignKey;

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun);

use App::DB::Migrate::Util;
use App::DB::Migrate::Config;
use App::DB::Migrate::Factory qw(id);

use parent qw(App::DB::Migrate::Constraint);

sub new {
    my ($class, $from_table, $to_table, $options) = @_;
    my $data = $class->SUPER::new($options);
    $data->{from_table} = $from_table || die('From table needed');
    die('To table needed') if !$to_table && !$options->{remove};
    $data->{to_table} = $to_table;
    return $data;
}

sub from_table { $_[0]->{from_table} }
sub to_table { $_[0]->{to_table} }

sub column { $_[0]->{options}->{column} || $_[0]->_get_column_name }
sub primary_key { $_[0]->{options}->{primary_key} || App::DB::Migrate::Config::id($_[0]->to_table) }

sub build_name { 'fk_'.$_[0]->from_table.'_'.$_[0]->column }

sub on_delete { $_[0]->{options}->{on_delete} }
sub on_update { $_[0]->{options}->{on_update} }

sub valid_rules {
    {
        cascade => 'CASCADE',
        nullify => 'SET NULL',
        restrict => 'RESTRICT'
    }
}

sub references { 'REFERENCES' }
sub on_delete_sql { 'ON DELETE' }
sub on_update_sql { 'ON UPDATE' }

sub _get_column_name {
    my $self = shift;
    (my $to_table = $self->to_table) =~ s/_+/ /g;
    (my $singular = noun($to_table)->singular) =~ s/\s+/_/g;
    return $singular.'_id';
}

sub _action_sql {
    my ($self, $action) = @_;
    my $action_method = "on_${action}_sql";
    return unless $self->can($action_method) && $self->$action_method;

    my $rule = $self->{options}->{"on_$action"};
    my $native_rule = $self->valid_rules($action)->{$rule // ''};
    return unless $native_rule;

    return $self->$action_method." $native_rule";
}

sub to_sql {
    my $self = shift;
    return '' if $self->{options}->{remove};

    my $on_delete = $self->_action_sql('delete');
    my $on_update = $self->_action_sql('update');
    my @elems = $self->add_constraint($self->references, id($self->to_table),
        '('.id($self->primary_key).')', $on_delete, $on_update);
    return $self->_join_elems(@elems);
}

return 1;
