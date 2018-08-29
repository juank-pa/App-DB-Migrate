package App::DB::Migrate::Informix::Constraint::PrimaryKey;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Constraint::PrimaryKey);

sub autoincrement { undef }
sub add_constraint { my $self = shift; push(@_, $self->constraint_sql); @_ }

return 1;
