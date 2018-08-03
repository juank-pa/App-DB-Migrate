package Migrate::Constraint;

use strict;
use warnings;

use Migrate::Util;
use Migrate::Factory qw(id);

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql };

sub new {
    my ($class, $options) = @_;
    return bless({ name => $options->{name} }, $class);
}

sub constraint { 'CONSTRAINT' }

sub identifier { $_[0]->{qname} //= id($_[0]->{name} || $_[0]->build_name) }
sub build_name {}

sub add_constraint { my $self = shift; unshift(@_, $self->constraint_sql); @_ }

sub constraint_sql {
    my $self = shift;
    return unless $self->constraint && $self->identifier->name;
    $self->_join_elems($self->constraint, $self->identifier);
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

return 1;
