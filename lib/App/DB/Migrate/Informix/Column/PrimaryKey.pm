package Migrate::Informix::Column::PrimaryKey;

use strict;
use warnings;

use parent qw(Migrate::Column::PrimaryKey);

sub default_datatype { 'serial' }

return 1;
