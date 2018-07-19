package Migrate::SQLite::Table;

use Migrate::Table;
use Migrate::Informix::Handler;

use parent qw(Migrate::Table);

sub temporary { 'TEMPORARY' }

return 1;
