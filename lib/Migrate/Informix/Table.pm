package Migrate::Informix::Table;

use parent qw(Migrate::Table);

sub temporary { 'TEMP' }
sub dbspace { Migrate::Config::config->{dbspace}? 'in '.Migrate::Config::config->{dbspace} : undef }

return 1;
