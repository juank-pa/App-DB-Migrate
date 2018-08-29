package Migrate::Informix::Constraint::ForeignKey;

use strict;
use warnings;

use parent qw(Migrate::Constraint::ForeignKey);

sub valid_rules { { cascade => 'CASCADE' } }
sub on_update { undef }

sub add_constraint { my $self = shift; push(@_, $self->constraint_sql); @_ }

return 1;
