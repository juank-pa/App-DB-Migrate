package Migrate::SQLizable;

use strict;
use warnings;

use overload
    fallback => 1,
    '""' => sub { $_[0]->to_sql };

sub to_sql { '' }

return 1;
