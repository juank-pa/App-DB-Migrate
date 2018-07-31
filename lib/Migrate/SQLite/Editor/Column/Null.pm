package Column::Null;

use strict;
use warnings;

sub new {
    return {}, $_[0];
}

sub name { '' }
sub is_null { 0 }

sub rename { 0 }
sub change_null { 0 }
sub change_default { 0 }

sub add_foreign_key { 0 }
sub remove_foreign_key { 0 }

sub to_sql { '' }

return 1;
