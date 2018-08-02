package Migrate::Informix::Identifier;

use strict;
use warnings;

use parent qw(Migrate::Identifier);

sub to_sql {
    my $self = shift;
    my $schema = ($self->is_qualified? Migrate::Config::config->{schema} : undef) || '';
    $schema = Migrate::Util::identifier_name($schema).'.' if $schema;
    return $schema.$self->{name};
}

return 1;
