package Migrate::Table;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);
use Migrate::Factory qw(class id id_column column reference);
use Migrate::Util;

# TODO:
# * Add support to 'as' paramteter to pass a SQL query instead of a block (ignore other options).
# * Add a create_join_table

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql };

sub new {
    my ($class, $name, $options) = @_;
    my $data = {
        name => $name || die("Table name is needed\n"),
        options => $options,
        columns => []
    };

    $data->{name} = id($name, 1);
    my $table = bless($data, $class);
    $table->push_primary_key($options->{primary_key}, { type => $options->{id}, autoincrement => 1 })
        if !exists($options->{id}) || $options->{id};
    return $table;
}

sub identifier { shift->{name} }
sub name { shift->identifier->name }
sub options { shift->{options}{options} }
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
    $self->push_column($_, $datatype, $options) for @_;
}

sub AUTOLOAD {
    my ($self, $name) = @_;
    my ($method) = our $AUTOLOAD =~ /::(\w+)$/;
    my $meth_ref = $self->can($method) // die("Invalid function: $method\n");
    goto &$meth_ref;
}

sub push_column { shift->_push_column(column(@_)) }
sub push_primary_key { my $self = shift; $self->_push_column(id_column($self->name, @_)) }

sub timestamps {
    my $self = shift;
    $self->_push_column(timestamp("${_}_at", @_)) for qw(updated created);
}

sub references {
    my ($self, $column, $options) = @_;
    $self->_push_column(reference($self->name, $column, $options));
}

sub to_sql {
    my $self = shift;
    my $columns = join(',', @{$self->{columns}});
    my $temporary = $self->is_temporary && $self->temporary;
    return $self->_join_elems('CREATE', $temporary, 'TABLE', $self->identifier, "($columns)", $self->options);
}

sub _join_elems { shift; Migrate::Util::join_elems(@_) }

sub _push_column { push(@{$_[0]->{columns}}, $_[1]) }

DESTROY {}

return 1;
