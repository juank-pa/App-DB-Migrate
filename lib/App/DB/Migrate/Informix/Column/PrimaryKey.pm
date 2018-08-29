package App::DB::Migrate::Informix::Column::PrimaryKey;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Column::PrimaryKey);

sub default_datatype { 'serial' }

return 1;
