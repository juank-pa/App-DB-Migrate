package App::DB::Migrate::Constraint::Default;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Constraint);

# TODO:
# * Add support to convert a numeric value coming from time()
#   to a driver specific formatted date.

sub new {
    my ($class, $default, $options) = @_;
    $options //= {};
    die('Datatype is needed') if !defined($options->{type}) && defined($default) && ref($default) ne 'HASH';
    my $data = $class->SUPER::new($options);
    $data->{type} = $options->{type};
    $data->{default} = $default;
    return $data;
}

sub current_timestamp { undef }
sub null { 'NULL' }
sub default { 'DEFAULT' }

sub type { $_[0]->{type} }
sub value { $_[0]->{default} }

sub _hash_arg { ref($_[0]->value) eq 'HASH' && $_[0]->value->{$_[1]} }

sub is_current_timestamp { $_[0]->_hash_arg('timestamp') }
sub true { 'TRUE' }
sub false { 'FALSE' }

sub quoted_default_value {
    my $self = shift;
    return $self->current_timestamp if $self->is_current_timestamp;
    return $self->null unless defined($self->value);
    return ($self->value? $self->true : $self->false) if $self->type->name eq 'boolean';
    return $self->type->quote($self->value);
}

sub to_sql { $_[0]->_join_elems($_[0]->add_constraint($_[0]->default, $_[0]->quoted_default_value)) }

return 1;
