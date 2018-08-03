package Migrate::Column::Timestamp;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Migrate::Factory qw(column);

sub new {
    my ($class, $name, $options) = @_;
    my $new_options = { default => { timestamp => 1 } };
    $new_options->{null} = $options->{null} if $options && defined($options->{null});
    my $col = column($name, 'datetime', $new_options);
    return bless({ column => $col }, $class);
}

# Delegates
sub name { $_[0]->{column}->name }
sub options { $_[0]->{column}->options }
sub datatype { $_[0]->{column}->datatype }
sub constraints { $_[0]->{column}->contraints }
sub index { $_[0]->{column}->index }
sub to_sql { $_[0]->{column}->to_sql }

return 1;
