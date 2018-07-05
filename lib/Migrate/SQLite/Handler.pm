package Migrate::SQLite::Handler;

use strict;
use warnings;

use List::Util qw(first);

use Migrate::Dbh qw(get_dbh);
use Migrate::Config;
use Migrate::SQLite::Table;

our @ISA = qw(Migrate::Handler);

sub pk_datatype { 'integer' }

sub datatypes {
    {
        string    => 'VARCHAR',
        char      => 'CHARACTER',
        text      => 'TEXT',
        integer   => 'INTEGER',
        float     => 'FLOAT',
        decimal   => 'DECIMAL',
        date      => 'DATE',
        time      => 'TIME',
        datetime  => 'DATETIME',
        timestamp => 'TIMESTAMP',
        boolean   => 'BOOLEAN',
    }
}

sub not_null { 'NOT NULL' }

sub null { undef }

sub current_timestamp { 'CURRENT_TIMESTAMP' }

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
    $self->push_sql(qq{ALTER TABLE $quoted_source_table ADD COLUMN $field_name CONSTRAINT fk_${source_table}_$field_name REFERENCES $target_table($field_name)});
}

sub create_migrations_table_sql { 'CREATE TABLE IF NOT EXISTS '.shift->migrations_table_name.' (migration_id VARCHAR(128) NOT NULL PRIMARY KEY)' }
sub select_migrations_sql { 'SELECT * FROM '.shift->migrations_table_name.' ORDER BY migration_id' };
sub insert_migration_sql { 'INSERT INTO '.shift->migrations_table_name.' (migration_id) VALUES (?)' }
sub delete_migration_sql { 'DELETE FROM '.shift->migrations_table_name.' WHERE migration_id = ?' }

return 1;
