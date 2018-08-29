package Migrate::Table;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Scalar::Util qw(looks_like_number);
use Migrate::Factory qw(class id id_column reference timestamp);
use Migrate::Util;

sub new {
    my ($class, $name, $options) = @_;
    my $data = {
        name => $name || die("Table name is needed"),
        options => $options,
        columns => []
    };

    $data->{name} = id($name, 1);
    my $table = bless($data, $class);
    $table->_push_primary_key($options->{primary_key}, { type => $options->{id}, autoincrement => 1 })
        if !$options->{as} && (!exists($options->{id}) || $options->{id});
    return $table;
}

sub identifier { shift->{name} }
sub name { shift->identifier->name }
sub as { shift->{options}->{as} }
sub options { shift->{options}->{options} }
sub is_temporary { shift->{options}{temporary} }
sub columns { $_[0]->{columns} }
sub temporary { }

sub can {
    my ($self, $method) = @_;
    my $meth_ref = $self->SUPER::can($method);
    return $meth_ref if $meth_ref;

    return unless class('datatype')->is_valid_datatype($method);

    $meth_ref = sub { splice(@_, 1, 0, $method); goto \&_shorthand_handler };
    no strict 'refs';
    return *{ $method } = $meth_ref;
}

sub _shorthand_handler {
    my $self = shift;
    my $datatype = shift;
    my $options;
    $options = pop if ref($_[-1]) eq 'HASH';
    $self->column($_, $datatype, $options) for @_;
}

sub AUTOLOAD {
    my ($self, $name) = @_;
    my ($method) = our $AUTOLOAD =~ /::(\w+)$/;
    my $meth_ref = $self->can($method) // die("Invalid function: $method");
    goto &$meth_ref;
}

sub column { shift->_push_column(Migrate::Factory::column(@_)) }
sub _push_primary_key { my $self = shift; $self->_push_column(id_column($self->name, @_)) }

sub timestamps {
    my $self = shift;
    $self->_push_column(timestamp("${_}_at", @_)) for qw(updated created);
}

sub references {
    my ($self, $column, $options) = @_;
    $self->_push_column(reference($self->name, $column, $options));
}

sub _as_syntax {
    my $self = shift;
    my $temporary = $self->is_temporary && $self->temporary;
    return $self->_join_elems($self->_add_options_as('CREATE', $temporary, 'TABLE', $self->identifier), 'AS', $self->as);
}

sub to_sql {
    my $self = shift;
    return $self->_as_syntax if $self->as;

    my $columns = join(',', @{$self->{columns}});
    my $temporary = $self->is_temporary && $self->temporary;
    return $self->_join_elems($self->_add_options('CREATE', $temporary, 'TABLE', $self->identifier, "($columns)"));
}

sub _add_options_as { shift->_add_options(@_) }

sub _add_options {
    my $self = shift;
    return (@_, Migrate::Config::config->{add_options}? $self->options : undef);
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

sub _push_column { push(@{$_[0]->{columns}}, $_[1]) }

DESTROY {}

return 1;
