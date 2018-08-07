package Migrate::Column;

use strict;
use warnings;

use Migrate::Factory qw(null default datatype id);
use Migrate::Util;

use parent qw(Migrate::SQLizable);

sub new {
    my ($class, $name, $datatype, $options) = @_;
    $options //= {};
    my $datatype_options = $class->_extract_datatype_options($options);
    my $data = {
        identifier => id($name) || die("Column name is needed\n"),
        type => datatype($datatype, $datatype_options),
        options => $options // {},
        constraints => []
    };

    my $col = bless($data, $class);

    $col->add_constraint(null($options->{null})) if exists($options->{null});
    $col->add_constraint(default($options->{default}, { type => $col->type })) if exists($options->{default});

    return $col;
}

sub identifier { $_[0]->{identifier} }
sub name { $_[0]->identifier->name }
sub options { $_[0]->{options} }
sub type { $_[0]->{type} }
sub constraints { $_[0]->{constraints} }
sub index { $_[0]->options->{index} }

sub add_constraint {
    my ($self, $constraint) = @_;
    push(@{$self->{constraints}}, $constraint);
}

sub _extract_datatype_options { Migrate::Util::extract_keys($_[1], ['limit', 'precision', 'scale']) }

sub to_sql {
    my $self = shift;
    return $self->_join_elems(
        $self->identifier,
        $self->type,
        @{$self->constraints}
    );
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

return 1;
