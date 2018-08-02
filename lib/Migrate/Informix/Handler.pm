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

sub rename_index {
    my ($self, $old_name, $new_name) = @_;
    $self->execute('RENAME INDEX '.create('name', $old_name, 1).' TO '.$new_name);
}

sub rename_table {
    my ($self, $old_name, $new_name) = @_;
    $self->execute('RENAME TABLE '.create('name', $old_name, 1).' TO '.$new_name);
}

sub rename_column {
    my ($self, $table, $old_name, $new_name) = @_;
    $self->execute('RENAME COLUMN '.create('name', $table, 1).'.'.create('name', $old_name).' TO '.$new_name);
}

sub add_foreign_key {
    my ($self, $table, $to, $options) = @_;
    'ALTER TABLE table ADD CONSTRAINT FOREIGN KEY (from_col) REFERENCES table (to_col) CONSTRAINT';
}

sub remove_foreign_key {
    my ($self, $table, $to, $options) = @_;
    'ALTER TABLE table DROP CONSTRAINT FOREIGN KEY constraint_name';
}

sub change_column {
    #'ALTER TABLE table MODIFY (column TYPE(SIZE) NULL DEFAULT)'
}

sub change_column_default {
    #'INFO COLUMNS FOR table (Column name, Type, Nulls)';
    #'ALTER TABLE table MODIFY (column TYPE(SIZE) DEFAULT)'
}

sub change_column_null {
    #'INFO COLUMNS FOR table';
    #'ALTER TABLE table MODIFY (column TYPE(SIZE) NULL)'
}

return 1;
