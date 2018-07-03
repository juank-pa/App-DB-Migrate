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

sub quotation { '"' }

sub create_index_for_pk { 0 }

sub add_primary_key {
    my $self = shift;
    my $table_name = shift;
    my $field_name = shift;
    $self->push_sql(qq{ALTER TABLE $Dbh::DBSchema$table_name ADD PRIMARY KEY (${field_name}) CONSTRAINT ${Dbh::DBSchema}pk_$table_name});
}

sub create_index {
    my $self = shift;
    my $name = $self->plural(shift);
    my $column = shift;
    my $unique = $self->unique(shift);
    $self->push_sql(qq{CREATE ${unique}INDEX ${Dbh::DBSchema}idx_${name}_${column} ON $name (${column})});
}

sub add_foreign_key {
    my ($self, $source, $target) = (shift, shift, shift);
    my $source_table = $self->plural($source);
    my $target_table = $self->plural($target);
    my $field_name = "${target}_id";
    $self->push_sql(qq{ALTER TABLE {$Dbh::DBSchema}$source_table ADD CONSTRAINT (FOREIGN KEY ($field_name) REFERENCES $target_table($field_name) CONSTRAINT "$Dbh::DBSchema".fk_${source_table}_$field_name)});
}

sub escape {
    my ($self, $text) = (shift, shift);
    my $quotation = $self->quotation;
    $text =~ s/(\'|\"|\\)/\\$1/g;
    return $text;
}

sub create_migrations_table {
    return (<<CREATE, <<INDEX, <<PK);
CREATE TABLE IF NOT EXISTS "$Dbh::DBSchema"._migrations (
    migration_id varchar(128)
);
CREATE
CREATE UNIQUE INDEX $Dbh::DBSchema.xu1_migrations_migration_id on _migrations (migration_id);
INDEX
ALTER TABLE $Dbh::DbSchema._migrations add constraint primary key (migration_id) constraint $Dbh::DbSchema.pk_migrations;
PK
}

return 1;
