package Migrate::Table;

use strict;
use warnings;

use Migrate::Handler;

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $name = shift;
    my $handler = shift;
    return bless { handler => $handler, name => $name, columns => [] }, $class;
}

sub name { shift(@_)->{name} }

sub AUTOLOAD {
    my ($self, $name, $options) = @_;
    (my $datatype = $AUTOLOAD) =~ s/(.*::)+//;
    $self->{handler}->is_valid_datatype($datatype) || die("Invalid function: $datatype\n");
    $self->column($name, $datatype, $options);
}

sub column {
    my $self = shift;
    my $name = shift // die('Column name is needed');
    my $datatype = shift // die('Data type is needed');
    my $options = shift // {};

    $self->{handler}->is_valid_datatype($datatype) || die("Invalid datatype: $datatype\n");

    $options->{name} = $name;
    $options->{str} = $self->_column_str($name, $datatype, $options);
    push(@{$self->{columns}}, $options);
}

sub _column_str {
    my $self = shift;
    my $name = shift;
    my $datatype = shift;
    my $options = shift // {};

    my $handler = $self->{handler};
    my $native_datatype = $handler->build_datatype($datatype, $options->{limit}, $options->{precision}, $options->{scale});

    my $null = $options->{null} || !defined($options->{null})? $handler->null : $handler->not_null;
    my $current_datetime = exists($options->{default_datetime})? $handler->default.' '.$handler->current_timestamp : undef;
    my $default = $handler->default.' '.$handler->quote($options->{default}, $datatype) if $options->{default};

    return $self->_join_column_elems($name, $native_datatype, $null, $current_datetime // $default);
}

sub _pk_column { }

sub timestamps {
    my $self = shift;
    my $handler = $self->{handler};
    $self->column('updated_at', 'datetime', { null => 0, default_datetime => 1 });
    $self->column('created_at', 'datetime', { null => 0, default_datetime => 1 });
}

sub _join_column_elems { shift; join ' ', grep { defined } @_; }

sub references {
    my $self = shift;
    my $name = shift;
    my $options = shift // {};
    my $handler = $self->{handler};
    my $target_table = $handler->plural($name);
    $options->{name} = $name;
    $options->{str} = $self->_column_str("${name}_id", 'integer', $options)." CONSTRAINT fk_$self->{name}_$name REFERENCES $target_table(${name}_id)";
    push(@{$self->{columns}}, $options);
}

return 1;
