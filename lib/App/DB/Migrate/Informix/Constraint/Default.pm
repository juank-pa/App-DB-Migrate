package App::DB::Migrate::Informix::Constraint::Default;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Constraint::Default);

sub add_constraint { shift; @_ }
sub current_timestamp { 'CURRENT YEAR TO SECOND' }

return 1;
