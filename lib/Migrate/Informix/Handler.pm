package Migrate::Informix::Handler;

use strict;
use warnings;

use parent qw(Migrate::Handler);

use Migrate::Factory qw(create);

# Foreign keys are automatically indexed in Informix so there is no need to index them again.
sub _add_indexes {
    my ($self, $table_name, @indexes) = @_;
    @indexes = grep { !$_->options || !$_->options->{foreign_key} } @indexes;
    $self->SUPER::_add_indexes($table_name, @indexes);
}

return 1;
