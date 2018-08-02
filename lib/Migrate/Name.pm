package Migrate::Name;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

sub new {
    my $class = shift;
    my $name = shift;
    my $qualified = shift // 0;
    return bless { name => $name, qualified => $qualified }, $class;
}

sub name { $_[0]->{name} }
sub is_qualified { $_[0]->{qualified} }

sub to_sql {
    my $self = shift;
    return $self->is_qualified
        ? Migrate::Util::qualified_name($self->name)
        : Migrate::Util::identifier_name($self->name);
}

return 1;
