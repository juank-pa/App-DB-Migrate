package App::DB::Migrate::Informix::Index;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Index);

use App::DB::Migrate::Util;

sub dbspace { App::DB::Migrate::Config::config->{dbspace}? 'IN '.App::DB::Migrate::Config::config->{dbspace} : undef }
sub using { 'USING' }

sub _add_options {
    my $self = shift;
    return $self->SUPER::_add_options(@_, $self->dbspace);
}


return 1;
