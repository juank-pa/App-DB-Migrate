package Migrate::Informix::Index;

use parent qw(Migrate::Index);

sub dbspace { Migrate::Config::config->{dbspace}? 'in '.Migrate::Config::config->{dbspace} : undef }

return 1;
