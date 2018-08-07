package Migrate::SQLite::Identifier;

use strict;
use warnings;

use parent qw(Migrate::Identifier);

sub new {
    my ($class, $name) = @_;
    return $class->SUPER::new($name);
}

return 1;
