package Migrate::Column::Timestamp;

use strict;
use warnings;

use parent qw(Migrate::Column);

sub new {
    my ($class, $name, $options) = @_;
    my $new_options = { default => { timestamp => 1 } };
    $new_options->{null} = $options->{null} if $options && defined($options->{null});
    return bless($class->SUPER::new($name, 'datetime', $new_options), $class);
}

return 1;
