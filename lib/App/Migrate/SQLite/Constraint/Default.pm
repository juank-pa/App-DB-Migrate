package Migrate::SQLite::Constraint::Default;

use strict;
use warnings;

use parent qw(Migrate::Constraint::Default);

sub current_timestamp { 'CURRENT_TIMESTAMP' }

return 1;
