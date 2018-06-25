package Migrate::Generate;

use strict;
use warnings;

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
    my %replace = get_replacements($package_name, $table_name, $data);

    open(my $src, '<', "$ENV{HOME}/perl/templates/$action.tl");
    open(my $tgt, '>', $target_filename);

    while (my $line = <$src>) {
        $line =~ s/\{$_\}/$replace{$_}/g foreach (keys %replace);
        print $tgt $line;
    }

    close($src); close($tgt);
    Log::debug("Created file: $target_filename");
}

sub get_replacements
{
    my ($package_name, $table_name, $data) = (shift, shift // '', shift // {});
    my $pk = "${table_name}_id";
    return (
        'PACKAGE_NAME' => $package_name,
        'DBTABLENAME' => $table_name,
        %$data
    );
}

sub generate_create_table
{
    my $table_name = shift;
    my $options = shift;
    my @columns;

    push(@columns, parse_columns($options->{c}));
    push(@columns, parse_columns($options->{r}, 1));

    if (exists $options->{t}) {
        push(@columns, 'timestamps');
    }

    my @foreign_keys = parse_foreign_keys($table_name, $options->{r}, 1);
    my $data = {
        'DBADDCOLUMNS' => join_lines(2, '$th->', @columns),
        'DBADDREFERENCES' => join_lines(1, '$mh->', @foreign_keys),
    };

    generate_file('create_table', $table_name, $table_name, $data);
}

sub join_lines
{
    my $tabs = ' ' x (scalar(shift) * 4);
    my $prefix = shift // '';
    my $ret = join("\n", map {"$tabs$prefix$_;"} @_);
    return $ret.($ret? "\n" : '');
}

sub parse_columns
{
    my $columns_str = shift // return ();
    my $is_ref = shift;
    my @columns = split qr/\s+/, $columns_str;
    return map { parse_column($_, $is_ref) // () } @columns;
}

sub parse_column
{
    my $column_str = shift // return undef;
    my $is_ref = shift;

    my @column_data = split(':', $column_str);

    my $column_name = shift(@column_data) // die('Column name is mandatory');
    my $column_type = 'string';
    my @options;

    foreach(@column_data) {
        when ('not_null') { push @options, 'null => 0' }
        when (/^(?:null|index|unique)$/) { push @options, "$_ => 1" }
        when (/^(string|char|text|integer|float|decimal|date|datetime)(?:\((\d+(?:,\d+)*)\))?$/) {
            $column_type = $1;
            if ($2) {
                my @attrs = split(',', $2);
                push(@options, "limit => $attrs[0]") if scalar(@attrs) == 1;
                push(@options, "precision => $attrs[0]", "scale => $attrs[1]") if scalar(@attrs) > 1;
            }
        }
    }

    my $options = @options? ', { '.join(', ', @options).' }' : '';
    return $is_ref? qq[references '$column_name'] :
                    qq[$column_type '$column_name'$options];
}

sub parse_foreign_keys
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
    my $source_table = shift;
    my $target_table = (split(':', scalar shift))[0];
    return qq{add_foreign_key '$source_table', '$target_table'};
}

sub drop_foreign_key
{
    my $source_table = shift;
    my $target_table = shift;
    return qq{remove_foreign_key '$source_table', '$target_table'};
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

sub getTimestamp
{
    my @time = gmtime();
    my @parts = reverse(@time[0..5]);
    $parts[0] += 1900;
    @time = map { sprintf("%02d", $_) } @parts;
    return join('', @time);
}

return 1;
