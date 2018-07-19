package Migrate::Column;

use strict;
use warnings;

use Migrate::Factory qw(create class);
use Migrate::Util;

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql };

# TODO: Add support to convert a numeric value coming from time()
#       to a driver specific formatted date.

sub new {
    my ($class, $name, $datatype, $options) = @_;
    my $datatype_options = $class->_extract_datatype_options($options);
    my $data = {
        name => $name || die("Column name is needed\n"),
        datatype => create('datatype', $datatype, $datatype_options),
        options => $options // {},
        constraints => []
    };

    my $col = bless($data, $class);

    $col->add_constraint(create('Constraint::Null', delete $options->{null})) if exists($options->{null});
    $col->add_constraint(create('Constraint::Default', delete $options->{default}, $col->datatype)) if exists($options->{default});

    return $col;
}

sub name { $_[0]->{name} }
sub options { $_[0]->{options} }
sub datatype { $_[0]->{datatype} }
sub constraints { $_[0]->{constraints} }
sub index { $_[0]->options->{index} }

sub add_constraint {
    my ($self, $constraint) = @_;
    push(@{$self->{constraints}}, $constraint);
}

sub _extract_datatype_options { Migrate::Util::extract_keys($_[1], qw(limit precision scale)) }

sub to_sql {
    my $self = shift;
    return $self->_join_elems(
        $self->name,
        $self->datatype,
        @{$self->constraints}
    );
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

return 1;
