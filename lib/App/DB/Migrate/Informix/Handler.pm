package App::DB::Migrate::Informix::Handler;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Handler);

use App::DB::Migrate::Factory qw(column reference id);

# Foreign keys are automatically indexed in Informix so there is no need to index them again.
sub _add_indexes {
    my ($self, $table_name, @indexes) = @_;
    @indexes = grep { !$_->options || !$_->options->{foreign_key} } @indexes;
    $self->SUPER::_add_indexes($table_name, @indexes);
}

sub rename_index {
    my ($self, undef, $old_name, $new_name) = @_;
    $self->execute('RENAME INDEX '.id($old_name, 1).' TO '.id($new_name));
}

sub rename_table {
    my ($self, $old_name, $new_name) = @_;
    $self->execute('RENAME TABLE '.id($old_name, 1).' TO '.id($new_name));
}

sub rename_column {
    my ($self, $table, $old_name, $new_name) = @_;
    $self->execute('RENAME COLUMN '.id($table, 1).'.'.id($old_name).' TO '.id($new_name));
}

sub change_column {
    my ($self, $table, $column, $datatype, $options) = @_;
    my $col = column('column', $column, $datatype, $options);
    $self->execute('ALTER TABLE '.id($table, 1).' MODIFY ('.$col.')');
}

sub change_column_default {
    die('Not yet implemented');
    #'INFO COLUMNS FOR table (Column name, Type, Nulls)';
    #'ALTER TABLE table MODIFY (column TYPE(SIZE) DEFAULT)'
}

sub change_column_null {
    die('Not yet implemented');
    #'INFO COLUMNS FOR table';
    #'ALTER TABLE table MODIFY (column TYPE(SIZE) NULL)'
}

return 1;
