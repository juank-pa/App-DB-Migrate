package Migrate::Generate;

use strict;
use warnings;

use Lingua::EN::Inflect qw{PL};

use feature 'switch';

sub execute
{
    my $options = shift;
    my $name = $options->{n} // die('Generate requires a migration name');

    given($name) {
        when ($name =~ s/^create_table_// > 0) { generate_create_table($name, $options) }
        when ($name =~ s/^drop_table_// > 0) { generate_drop_table($name) }
        when ($name =~ s/^add_column_// > 0) { generate_add_column($name) }
        when ($name =~ s/^drop_column_// > 0) { generate_add_column($name) }
        default { generate_generic($name) }
    }
}

sub generate_file
{
    my ($action, $subject, $table_name, $data) = (shift, shift, shift, shift);

    my $package_subject = $action eq 'generic'? $subject : "${action}_$subject";
    my $package_name = getTimestamp()."_${package_subject}";
    my $target_filename = "migrations/$package_name.pl";
    my %replace = getReplacements($package_name, $table_name, $data);

    open(my $src, '<', "$ENV{HOME}/perl/templates/$action.tl");
    open(my $tgt, '>', $target_filename);

    while (my $line = <$src>) {
        $line =~ s/\{$_\}/$replace{$_}/g foreach (keys %replace);
        print $tgt $line;
    }

    close($src); close($tgt);
    Log::debug("Created file: $target_filename");
}

sub getReplacements
{
    my ($package_name, $table_name, $data) = (shift, shift // '', shift // {});
    my $pk = "${table_name}_id";
    return (
        'PACKAGE_NAME' => $package_name,
        'DBSCHEMA' => $Dbh::DBSchema,
        'DBTABLENAME' => plural($table_name),
        'DBTABLEPK' => $pk,
        %$data
    );
}

sub generate_create_table
{
    my $table_name = shift;
    my $options = shift;
    my @columns = ("${table_name}_id serial");

    push(@columns, parse_columns($options->{c}));
    push(@columns, parse_columns($options->{r}, 1));

    if (exists $options->{t}) {
        my @timestamps = ('created_at', 'updated_at');
        @timestamps = map { "$_ DATETIME YEAR TO SECOND DEFAULT CURRENT DATETIME YEAR TO SECOND NOT NULL" } @timestamps;
        push(@columns, @timestamps);
    }

    my $data = {
        'DBADDCOLUMNS' => join(",\n", map {"  $_"} @columns),
        'DBADDREFERENCES' => join("\n", parse_references($table_name, $options->{r}, 1)),
        'DBDROPREFERENCES' => join("\n", parse_references($table_name, $options->{r}, 0)),
    };

    generate_file('create_table', $table_name, $table_name, $data);
}

sub parse_columns
{
    my $columns_str = shift // return ();
    my $is_ref = shift;
    my @columns = split ',', $columns_str;
    return map { parse_column($_, $is_ref) // () } @columns;
}

sub parse_column
{
    my $column_str = shift // return undef;
    my $is_ref = scalar(shift)? '_id' : '';

    my $default_type = $is_ref? 'INTEGER' : 'VARCHAR';
    my @column_data = split(':', $column_str);

    my $column_name = $column_data[0] // die('Column name is mandatory');
    my ($column_type, $not_null) = ($default_type, '');

    foreach(@column_data[1..$#column_data]) {
        when ('not_null') { $not_null = ' NOT NULL'}
        default { $column_type = uc($_) }
    }

    return "$column_name$is_ref $column_type$not_null";
}

sub parse_references
{
    my $table_name = shift;
    my $columns_str = shift // return ();
    my $is_add_mode = shift;
    my @columns = split ',', $columns_str;
    my $column_parser = $is_add_mode? \&add_foreign_key : \&drop_foreign_key;
    return map { $column_parser->($table_name, $_) } @columns;
}

sub add_foreign_key
{
    my $source_table = plural(shift);
    my $target_table = (split(':', scalar shift))[0];
    my $field_name = $target_table . '_id';
    $target_table = plural($target_table);
    return qq{ALTER TABLE "$Dbh::DBSchema".$source_table ADD CONSTRAINT (FOREIGN KEY ($field_name) REFERENCES $target_table($field_name) CONSTRAINT "$Dbh::DBSchema".fk_${source_table}_$field_name)};
}

sub drop_foreign_key
{
    my $source_table = plural(shift);
    my $field_name = (split(':', scalar shift))[0].'_id';
    return qq{DROP CONSTRAINT "$Dbh::DBSchema".fk_${source_table}_$field_name);};
}

sub generate_drop_table
{
    my $migration_name = shift;
    generate_file('generic', "drop_table_$migration_name");
}

sub generate_add_column
{
    my $migration_name = shift;
    generate_file('generic', "add_column_$migration_name");
}

sub generate_drop_column
{
    my $migration_name = shift;
    generate_file('generic', "drop_column_$migration_name");
}

sub generate_generic
{
    my $migration_name = shift;
    generate_file('generic', $migration_name);
}

sub plural
{
    (my $table_name = shift) =~ s/_+/ /g;
    $table_name = PL($table_name);
    $table_name =~ s/\s+/_/g;
    return $table_name;
}

sub getTimestamp
{
    my @time = gmtime();
    my @parts = reverse(@time[0..5]);
    $parts[0] += 1900;
    @time = map { sprintf("%02d", $_) } @parts;
    return join('', @time);
}

return 1;
