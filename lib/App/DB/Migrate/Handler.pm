package App::DB::Migrate::Handler;

use strict;
use warnings;

use App::DB::Migrate::Config;
use App::DB::Migrate::Util;
use App::DB::Migrate::Factory qw(column timestamp foreign_key table_index table id reference);
use App::DB::Migrate::Dbh qw{get_dbh};
use Lingua::EN::Inflexion qw(noun);
use DBI;

use feature 'say';

sub new {
    my ($class, $dry, $output) = @_;
    bless { dry => $dry, output => $output }, $class;
}

sub execute {
    my $self = shift;
    my @sqls = @_;
    my $dbh = get_dbh();
    my $output = $self->{output};
    for my $sql (@sqls) {
        if (!$self->{dry}) {
            my $sth = $dbh->prepare($sql) or die("$DBI::errstr\n$sql");
            $sth->execute() or die("$DBI::errstr\n$sql");
        }
        (say $output "$sql;") if $output;
    }
}

sub create_table {
    my ($self, $name, $options, $sub) = @_;
    ($sub, $options) = ($options, undef) if ref($options) eq 'CODE';
    my $table = table($name, $options);

    $sub->($table) unless $options->{as};
    $self->execute($table);
    $self->_add_indexes($table->name, @{$table->columns});
}

sub _add_indexes {
    my ($self, $table, @indexes) = @_;
    @indexes = grep { $_->index } @indexes;
    $self->add_index($table, $_->name, $self->_get_index_options($_)) for @indexes;
}

sub _get_index_options { $_[1]->index if ref($_[1]->index) eq 'HASH' }

sub add_column {
    my ($self, $table, $column, $datatype, $options) = @_;
    $self->add_raw_column($table, column($column, $datatype, $options));
}

sub add_reference {
    my ($self, $table, $ref_name, $options) = @_;
    $self->add_raw_column($table, reference($table, $ref_name, $options));
}

sub add_timestamps {
    my ($self, $table, $options) = @_;
    $self->add_raw_column($table, timestamp('updated_at', $options));
    $self->add_raw_column($table, timestamp('created_at', $options));
}

sub add_raw_column {
    my ($self, $table, $column) = @_;
    $self->execute('ALTER TABLE '.id($table, 1).' ADD '.$column);
    $self->_add_indexes($table, $column);
}

sub add_index { shift->execute(table_index(@_)) }

sub drop_table {
    my ($self, $table) = @_;
    $self->execute('DROP TABLE '.id($table, 1));
}

sub remove_column {
    my ($self, $table, $column) = @_;
    $self->execute('ALTER TABLE '.id($table, 1).' DROP '.id($column));
}

sub remove_columns {
    my ($self, $table, @columns) = @_;
    $self->remove_column($table, $_) for @columns;
}

sub remove_reference {
    my ($self, $table, $name) = @_;
    my $id_name = "${name}_id";
    $self->remove_column($table, $id_name);
}

sub remove_timestamps { $_[0]->remove_columns($_[1], 'created_at', 'updated_at') }

sub _remove_index {
    my ($self, $index) = @_;
    $self->execute('DROP INDEX '.id($index->name, 1));
}

sub remove_index {
    my ($self, $table, $options_or_column) = @_;
    my $options = ref($options_or_column) eq 'HASH'? $options_or_column : undef;
    my $column = $options? 'dummy' : $options_or_column;
    $self->_remove_index(table_index($table, $column, $options));
}

sub irreversible {
    die("Migration is irreversible!");
}

sub rename_table;
sub rename_index;
sub rename_column;

sub _add_foreign_key {
    my ($self, $from_table, $fk) = @_;
    $self->execute('ALTER TABLE '.id($from_table, 1).' ADD CONSTRAINT FOREIGN KEY ('.$fk->column.') '.$fk);
}

sub _remove_foreign_key {
    my ($self, $from_table, $fk) = @_;
    $self->execute('ALTER TABLE '.id($from_table, 1).' DROP CONSTRAINT '.$fk->name);
}

sub add_foreign_key {
    my ($self, $from_table, $to_table, $options) = @_;
    my $fk = foreign_key($from_table, $to_table, $options);
    $self->_add_foreign_key($from_table, $fk);
}

sub remove_foreign_key {
    my ($self, $from_table, $options_or_to_table) = @_;
    my $options = ref($options_or_to_table) eq 'HASH'? $options_or_to_table : undef;
    my $to_table = $options? undef : $options_or_to_table;
    $options->{remove} = 1;
    my $fk = foreign_key($from_table, $to_table, $options);
    $self->_remove_foreign_key($from_table, $fk);
}

sub change_column;

sub change_column_default;
sub change_column_null;

sub _join_table_name {
    my ($self, $table_1, $table_2, $options) = @_;
    return $options->{table_name} if $options->{table_name};
    return "${table_1}_$table_2";
}

sub create_join_table {
    my ($self, $table_1, $table_2, $options) = @_;
    $options //= {};
    $options->{id} = 0;
    my $col_options = $options->{column_options} // {};
    $col_options->{index} = 0;
    my $table_name = $self->_join_table_name($table_1, $table_2, $options);
    $self->create_table($table_name, $options, sub {
       my $th = shift;
       $th->references(noun($table_1)->singular, $col_options);
       $th->references(noun($table_2)->singular, $col_options);
    });
}

sub drop_join_table {
    my ($self, $table_1, $table_2) = @_;
    $self->drop_table("${table_1}_$table_2");
}

return 1;
