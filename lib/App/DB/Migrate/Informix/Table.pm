package App::DB::Migrate::Informix::Table;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Table);

sub temporary { 'TEMP' }
sub dbspace { App::DB::Migrate::Config::config->{dbspace}? 'IN '.App::DB::Migrate::Config::config->{dbspace} : undef }

sub _add_options {
    my $self = shift;
    return $self->SUPER::_add_options(@_, $self->dbspace);
}

return 1;
