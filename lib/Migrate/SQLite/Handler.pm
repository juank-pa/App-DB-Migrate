package Migrate::SQLite::Handler;

use strict;
use warnings;

use List::Util qw(first);

use Migrate::Dbh qw(get_dbh);
use Migrate::Config;
use Migrate::SQLite::Table;

our @ISA = qw(Migrate::Handler);

sub pk_datatype { 'INTEGER' }

sub string_datatype { 'VARCHAR' }

sub char_datatype { 'CHARACTER' }

sub text_datatype { 'TEXT' }

sub integer_datatype { 'INTEGER' }

sub float_datatype { 'FLOAT' }

sub decimal_datatype { 'DECIMAL' }

sub date_datatype { 'DATE' }

sub datetime_datatype { 'DATETIME' }

sub boolean_datatype { 'BOOLEAN' }

sub not_null { 'NOT NULL' }

sub null { undef }

sub default_datatype { shift->string_datatype }

sub default { 'DEFAULT' }

sub current_timestamp { 'CURRENT_TIMESTAMP' }

sub quoted_types { qw{VARCHAR CHARACTER TEXT DATE DATETIME} }

sub should_quote {
    my ($self, $datatype) = @_;
    foreach ($self->quoted_types) {
        return 1 if ($_ eq $datatype);
    }
    return 0;
}

sub quote {
    my ($self, $value) = @_;
    my $datatype = shift // $self->default_datatype;
    return get_dbh()->quote($value) if $self->should_quote($datatype);
    return $value;
}

sub create_index_for_pk { 0 }

sub add_primary_key { }

sub schema_prefix { '' }

sub create_index {
    my $self = shift;
    my $table_name = $self->plural(shift);
    my $column = shift;
    my $unique = $self->unique(shift);
    $self->push_sql(qq{CREATE ${unique}INDEX idx_${table_name}_${column} ON $table_name($column)});
}

sub add_foreign_key {
    my ($self, $source, $target) = (shift, shift, shift);
    my $source_table = $self->plural($source);
    my $target_table = $self->plural($target);
    my $field_name = "${target}_id";
    $self->push_sql(qq{ALTER TABLE $source_table ADD COLUMN $field_name CONSTRAINT fk_${source_table}_$field_name REFERENCES $target_table($field_name)});
}

sub escape {
    my ($self, $text) = (shift, shift);
    my $quotation = $self->quotation;
    $text =~ s/(\'|\"|\\)/\\$1/g;
    return $text;
}

sub create_migrations_table_sql { 'CREATE TABLE IF NOT EXISTS _migrations (migration_id VARCHAR(128) NOT NULL PRIMARY KEY)' }
sub select_migrations_sql { 'SELECT * FROM _migrations ORDER BY migration_id' };
sub insert_migration_sql { "INSERT INTO _migrations (migration_id) VALUES (?)" }
sub delete_migration_sql { "DELETE FROM _migrations WHERE migration_id = ?" }

return 1;
