package Migrate::Constraint;

use strict;
use warnings;

use Migrate::Util;

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql };

sub new {
    my ($class, $options) = @_;
    my $data = { options => $options // {} };
    return bless($data, $class);
}

sub constraint { 'CONSTRAINT' }

sub name { Migrate::Util::identifier_name($_[0]->{options}->{name} || $_[0]->build_name) }
sub build_name {}

sub to_sql {
    my $self = shift;
    return unless $self->constraint && $self->name;
    Migrate::Util::join_elems($self->constraint, $self->name);
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

return 1;
