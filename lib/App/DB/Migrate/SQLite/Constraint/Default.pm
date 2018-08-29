package App::DB::Migrate::SQLite::Constraint::Default;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Constraint::Default);

sub current_timestamp { 'CURRENT_TIMESTAMP' }

return 1;
