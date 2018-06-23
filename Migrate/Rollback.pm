package Migrate::Rollback;

use strict;
use warnings;

use Dbh;
use Migrate::Common qw{migrations_up};

sub execute
{
    Migrate::Common::migrations_down();
}

return 1;
