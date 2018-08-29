package App::DB::Migrate::Informix::Identifier;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Identifier);

sub to_sql {
    my $self = shift;
    my $schema = ($self->is_qualified? App::DB::Migrate::Config::config->{owner} : undef) || '';
    $schema = App::DB::Migrate::Util::identifier_name($schema).'.' if $schema;
    return $schema.$self->{name};
}

return 1;
