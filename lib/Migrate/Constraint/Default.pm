package Migrate::Constraint::Default;

use strict;
use warnings;

use parent qw(Migrate::Constraint);

# TODO:
# * Add support to convert a numeric value coming from time()
#   to a driver specific formatted date.

sub new {
    my ($class, $default, $options) = @_;
    $options //= {};
    die("Datatype is needed\n") if !defined($options->{type}) && defined($default) && ref($default) ne 'HASH';
    my $data = $class->SUPER::new($options);
    $data->{default} = $default;
    return bless($data, $class);
}

sub current_timestamp { undef }
sub null { 'NULL' }
sub default { 'DEFAULT' }

sub datatype { $_[0]->{options}->{type} }
sub value { $_[0]->{default} }

sub _hash_arg { ref($_[0]->value) eq 'HASH' && $_[0]->value->{$_[1]} }

sub is_current_timestamp { $_[0]->_hash_arg('timestamp') }
sub true { 'TRUE' }
sub false { 'FALSE' }

sub _quoted_default_value {
    my $self = shift;
    return $self->current_timestamp if $self->is_current_timestamp;
    return $self->null unless defined($self->value);
    return ($self->value? $self->true : $self->false) if $self->datatype->name eq 'boolean';
    return $self->datatype->quote($self->value);
}

sub to_sql { $_[0]->_join_elems($_[0]->add_constraint($_[0]->default, $_[0]->_quoted_default_value)) }

return 1;
