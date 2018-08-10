package Migrate::Column::Timestamp;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Migrate::Factory qw(column);

sub new {
    my ($class, $name, $options) = @_;
    my $new_options = { %{ $options // {} }};
    $new_options->{default} = { timestamp => 1 };
    my $col = column($name, $class->default_datatype, $new_options);
    return bless({ column => $col }, $class);
}

sub default_datatype { 'datetime' }

# Delegates
sub name { $_[0]->{column}->name }
sub options { $_[0]->{column}->options }
sub type { $_[0]->{column}->type }
sub constraints { $_[0]->{column}->constraints }
sub index { $_[0]->{column}->index }
sub to_sql { $_[0]->{column}->to_sql }

return 1;
