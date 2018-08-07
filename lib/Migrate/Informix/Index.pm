package Migrate::Informix::Index;

use strict;
use warnings;

use parent qw(Migrate::Index);

use Migrate::Util;

sub dbspace { Migrate::Config::config->{dbspace}? 'IN '.Migrate::Config::config->{dbspace} : undef }
sub using { 'USING' }

sub _add_options {
    my $self = shift;
    return $self->SUPER::_add_options(@_, $self->dbspace);
}


return 1;
