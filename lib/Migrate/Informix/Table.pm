package Migrate::Informix::Table;

use strict;
use warnings;

use parent qw(Migrate::Table);

sub temporary { 'TEMP' }
sub dbspace { Migrate::Config::config->{dbspace}? 'IN '.Migrate::Config::config->{dbspace} : undef }

sub _add_options {
    my $self = shift;
    return $self->SUPER::_add_options(@_, $self->dbspace);
}

return 1;
