package Migrate::Constraint::Default;

use strict;
use warnings;

use overload
    fallback => 1,
    '""' => \&to_sql;

# TODO:
# * Add support to convert a numeric value coming from time()
#   to a driver specific formatted date.

sub new {
    my ($class, $default, $datatype) = @_;
    die("Datatype is needed\n") if !defined($datatype) && defined($default) && ref($default) ne 'HASH';
    return bless({ default => $default, datatype => $datatype }, $class);
}

sub current_timestamp { undef }
sub null { 'NULL' }
sub default { 'DEFAULT' }

sub datatype { $_[0]->{datatype} }
sub value { $_[0]->{default} }

sub _hash_arg { ref($_[0]->value) eq 'HASH' && $_[0]->value->{$_[1]} }

sub is_current_timestamp { $_[0]->_hash_arg('timestamp') }

sub _quoted_default_value {
    my $self = shift;
    return $self->current_timestamp if $self->is_current_timestamp;
    return $self->null unless defined($self->value);
    return $self->datatype->quote($self->value);
}

sub to_sql { $_[0]->default.' '.$_[0]->_quoted_default_value }

return 1;
