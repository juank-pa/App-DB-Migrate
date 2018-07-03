package Migrate::Generate;

use strict;
use warnings;

use feature 'say';

use Migrate::Config;
use File::Spec;
use Data::Dumper;

sub execute {
    my $options = shift;
    my $name = $options->{name} // die("Generate requires a migration name\n");
    my $path;

    for ($name) {
        if (/^create_table_(.*)/) { $path = _generate_create_table_from_opts($1, $options) }
        elsif (/^drop_table_(.*)/) { $path = generate_drop_table($1) }
        elsif (/^add_column_(.*)/) { $path = generate_add_column($1) }
        elsif (/^drop_column_(.*)/) { $path = generate_add_column($1) }
        else { generate_generic($name) }
    }

    say("Generated file: $path") if $path;
}

sub generate_create_table {
    my $table_name = shift;
    my $cols = shift // [];
    my $refs = shift // [];
    my $timestamps = shift;

    my @columns = (_serialize_columns($cols), _serialize_columns($refs, 1));
    push(@columns, 'timestamps') if ($timestamps);

    my @foreign_keys = _serialize_foreign_keys($table_name, $refs, 1);
    my $data = {
        'DBADDCOLUMNS' => _join_lines(2, '$th->', @columns),
        'DBADDREFERENCES' => _join_lines(1, '$mh->', @foreign_keys),
    };

    _generate_file('create_table', $table_name, $table_name, $data);
}

sub generate_drop_table {
    my $table_name = shift;
    _generate_file('generic', "drop_table_$table_name");
}

sub generate_add_column {
    my $migration_name = shift;
    _generate_file('generic', "add_column_$migration_name");
}

sub generate_drop_column {
    my $migration_name = shift;
    _generate_file('generic', "drop_column_$migration_name");
}

sub generate_generic { _generate_file('generic', shift) }

sub _join_lines {
    my $tabs = ' ' x (scalar(shift) * 4);
    my $prefix = shift // '';
    my $ret = join("\n", map {"$tabs$prefix$_;"} @_);
    return $ret.($ret? "\n" : '');
}

# Private generators:
# They receive command line options instead of hashes so they need to first
# parse command line option strings into hashes to send them to public generator methods.

sub _generate_create_table_from_opts {
    my $table_name = shift;
    my $options = shift;
    my @columns = _parse_columns_opts($options->{column});
    my @refs = _parse_columns_opts($options->{ref});

    generate_create_table($table_name, \@columns, \@refs, $options->{tstamps});
}

# File generator

sub _generate_file {
    my ($action, $subject, $table_name, $data) = (shift, shift, shift, shift);

    my $package_subject = $action eq 'generic'? $subject : "${action}_$subject";
    my $package_name = _timestamp()."_${package_subject}";
    my %replace = _get_replacements($table_name, $data);

    my $target_path = File::Spec->catfile('db', 'migrations', "$package_name.pl");
    my $source_path = File::Spec->catfile(Migrate::Config::library_root, 'templates', "$action.tl");

    open(my $src, '<', $source_path);
    open(my $tgt, '>', $target_path);

    while (my $line = <$src>) {
        $line =~ s/\{$_\}/$replace{$_}/g foreach (keys %replace);
        print $tgt $line;
    }

    close($src); close($tgt);
    return $target_path;
}

sub _get_replacements {
    my ($table_name, $data) = (shift // '', shift // {});
    my $pk = "${table_name}_id";
    return (
        'DBTABLENAME' => $table_name,
        %$data
    );
}

# PARSER
# Parser functions convert from command line options to column hashrefs

sub _parse_columns_opts {
    my $columns = shift // return ();
    return map { _parse_column_opts($_) // () } @$columns;
}

sub _parse_column_opts {
    my $column_str = shift // return undef;

    my @column_data = split(':', $column_str);

    my $column_name = shift(@column_data) // die('Column name is required');
    my $options = { name => $column_name };
    my $datatype_regex = qr/^(string|char|text|integer|float|decimal|date|datetime)(\d+(?:,\d+)*)?$/;

    foreach(@column_data) {
        if ($_ eq 'not_null') { $options->{null} = 0 }
        elsif (/^(?:index|unique)$/) { $options->{$_} = 1 }
        elsif (/$datatype_regex/) { _parse_column_datatype($options, $1, $2) }
    }

    return $options;
}

sub _parse_column_datatype {
    my $options = shift;
    my ($type, $props) = @_;
    $options->{type} = $type;
    if ($props) {
        my @attrs = split(',', $props);
        $options->{limit} = $attrs[0] if scalar(@attrs) == 1;
        @$options{'precision', 'scale'} = @attrs if scalar(@attrs) > 1;
    }
}

# SERIALIZER
# Converts an array of column definition hashrefs to code lines for the generator

sub _serialize_columns {
    my $columns = shift // return ();
    my $is_ref = shift;
    return map { _serialize_column($_, $is_ref) // () } @$columns;
}

sub _serialize_column {
    my $options = { %{shift(@_)} } // {};
    my $is_ref = shift;
    my $column_name = delete $options->{name} // die('Column name is required');
    my $column_type = delete $options->{type} // 'string';
    my $options_str = _serialize_column_options($options);
    return $is_ref? qq[references('$column_name')] : qq[$column_type('$column_name'$options_str)];
}

sub _serialize_column_options {
    my $options = shift // {};
    $Data::Dumper::Indent = 0;
    $Data::Dumper::Quotekeys = 0;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Sortkeys = 1;
    return scalar keys %$options? ', '.Data::Dumper::Dumper($options) : '';
}

sub _serialize_foreign_keys {
    my $table_name = shift;
    my $columns = shift // return ();
    my $is_add_mode = shift;
    my $column_parser = $is_add_mode? \&_add_foreign_key : \&_drop_foreign_key;
    return map { $column_parser->($table_name, $_->{name}) } @$columns;
}

sub _add_foreign_key {
    my $source_table = shift;
    my $target_table = shift;
    return qq{add_foreign_key '$source_table', '$target_table'};
}

sub _drop_foreign_key {
    my $source_table = shift;
    my $target_table = shift;
    return qq{remove_foreign_key '$source_table', '$target_table'};
}

sub _timestamp {
    my @time = gmtime();
    my @parts = reverse(@time[0..5]);
    $parts[0] += 1900;
    @time = map { sprintf("%02d", $_) } @parts;
    return join('', @time);
}

return 1;
