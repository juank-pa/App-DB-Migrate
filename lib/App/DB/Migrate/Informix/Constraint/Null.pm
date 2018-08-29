package App::DB::Migrate::Informix::Constraint::Null;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Constraint::Null);

sub add_constraint { my $self = shift; push(@_, $self->constraint_sql); @_ }
sub null { '' }

return 1;
