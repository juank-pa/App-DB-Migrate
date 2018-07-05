package Migrate::Informix::Handler;

use Migrate::Informix::Table;

our @ISA = qw(Migrate::Handler);

sub pk_datatype { 'serial' }

sub string_datatype { 'VARCHAR' }

sub char_datatype { 'CHAR' }

sub text_datatype { 'TEXT' }

sub integer_datatype { 'INTEGER' }

sub float_datatype { 'FLOAT' }

sub decimal_datatype { 'DECIMAL' }

sub date_datatype { 'DATE' }

sub datetime_datatype { 'DATETIME YEAR TO SECOND' }

sub boolean_datatype { 'BOOLEAN' }

sub not_null { 'NOT NULL' }

sub null { undef }

sub default_datatype { shift->string_datatype }

sub default { 'DEFAULT' }

sub current_timestamp { 'CURRENT YEAR TO SECOND' }

sub quoted_types { qw{string char text date datetime} }

sub create_index_for_pk { 0 }

sub schema_prefix { '' }

sub create_index {
    my $self = shift;
    my $table_name = $self->plural(shift);
    my $quoted_table_name = $self->table_name($table_name);
    my $column = shift;
    my $unique = $self->unique(shift);
    $self->push_sql(qq{CREATE ${unique}INDEX idx_${table_name}_${column} ON $quoted_table_name($column)});
}

sub add_foreign_key {
    my ($self, $source, $target) = (shift, shift, shift);
    my $source_table = $self->plural($source);
    my $quoted_source_table = $self->table_name($source_table);
    my $target_table = $self->table_name($self->plural($target));
    my $field_name = "${target}_id";
    $self->push_sql(qq{ALTER TABLE $quoted_source_table ADD CONSTRAINT (FOREIGN KEY ($field_name) REFERENCES $target_table($field_name) CONSTRAINT fk_${source_table}_$field_name)});
}

sub create_migrations_table_sql { 'CREATE TABLE IF NOT EXISTS '.shift->migrations_table_name.' (migration_id VARCHAR(128) PRIMARY KEY)' }
sub select_migrations_sql { 'SELECT * FROM '.shift->migrations_table_name.' ORDER BY migration_id' };
sub insert_migration_sql { 'INSERT INTO '.shift->migrations_table_name.' (migration_id) VALUES (?)' }
sub delete_migration_sql { 'DELETE FROM '.shift->migrations_table_name.' WHERE migration_id = ?' }

return 1;
