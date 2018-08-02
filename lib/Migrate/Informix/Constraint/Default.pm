package Migrate::Informix::Constraint::Default;

use strict;
use warnings;

use parent qw(Migrate::Constraint::Default);

sub add_constraint { shift; @_ }

return 1;
