package Migrate::Generate;

use strict;
use warnings;

use feature 'say';

use Migrate::Config;
use File::Spec;
use Data::Dumper;

use constant CREATE => 'create';
use constant DROP => 'drop';
use constant ADD => 'add';
use constant REMOVE => 'remove';

sub execute {
    my $options = shift;
    my $name = $options->{name} // die("Generate requires a migration name (option --name or -n)\n");
    my $path;
    my $actions = join '|', (CREATE, DROP, ADD, REMOVE);

    for ($name) {
        if (/^($actions)_(.*)$/) { $path = _generate_columns_from_opts($1, $2, $options) }
        else { $path = generate_generic($name) }
    }

    say("Generated file: $path") if $path;
}

sub generate_columns {
    my $action = shift;
    my $subject = shift;
    my $table = _get_table_name($action, $subject);
    my $data = _get_column_template_data($action, $table, @_);
    _generate_file($action, $subject, $table, $data);
}

sub generate_drop_table { _generate_file(@_, $_[1]) }
sub generate_generic { _generate_file('generic', shift) }

sub _join_lines {
    my $tabs = ' ' x (scalar(shift) * 4);
    my $prefix = shift // '';
    my $ret = join("\n", map {"$tabs$prefix$_;"} @_);
    return $ret.($ret? "\n" : '');
}

sub _get_table_name {
    my $action = shift;
    my $subject = shift;
    return $subject if _is_table_action($action);
    return ($subject =~ /_to_(.+)$/)[0] if $action eq ADD;
    return ($subject =~ /_from_(.+)$/)[0];
}

sub _get_column_template_data {
    my $action = shift;
    my $table = shift;

    my @add_columns = _get_serialized_columns(_is_table_action($action)? $action : ADD, $table, @_);
    my @remove_columns = _is_table_action($action)? () : _get_serialized_columns(REMOVE, $table, @_);

    @add_columns = reverse @add_columns if $action eq REMOVE;
    @remove_columns = reverse @remove_columns if $action eq ADD;

    my $tabs = _is_table_action($action)? 2 : 1;
    my $handler = _is_table_action($action)? 'th' : 'mh';

    return {
        'DBADDCOLUMNS' => _join_lines($tabs, "\$$handler->", @add_columns),
        'DBREMOVECOLUMNS' => _join_lines($tabs, "\$$handler->", @remove_columns),
    };
}

sub _get_serialized_columns {
    my $action = shift;
    my $table = shift;
    my $cols = shift // [];
    my $refs = shift // [];
    my $timestamps = shift;
    return (
        _serialize_columns($action, $table, $cols),
        _serialize_references($action, $table, $refs),
        $timestamps? _serialize_timestamps($action, $table) : ()
    );
}

# Private generators:
# They receive command line options instead of hashes so they need to first
# parse command line option strings into hashes to send them to public generator methods.

sub _is_table_action { $_[0] eq CREATE || $_[0] eq DROP }

sub _generate_columns_from_opts {
    my $action = shift;
    my $subject = shift;
    my $options = shift;
    my @columns = _parse_columns_opts($options->{column});
    my @refs = _parse_columns_opts($options->{ref});
    my $has_columns = scalar @columns || scalar @refs;
    my $has_timestamps = $options->{tstamps};
    my $infer_column = !_is_table_action($action) && !$has_columns && !$has_timestamps;
    push(@columns, _get_column_from_subject($action, $subject)) if $infer_column;

    generate_columns($action, $subject, \@columns, \@refs, $options->{tstamps});
}

sub _get_column_from_subject {
    my $action = shift;
    my $subject = shift;
    my $re = $action eq ADD? qr/(.+)_to_.+/ : qr/(.+)_from_.+/;
    return { name => ($subject =~ /^$re$/)[0] };
}

# File generator

sub _generate_file {
    my ($action, $subject, $table, $data) = @_;

    my $migration_name = $action eq 'generic'? $subject : "${action}_$subject";
    my $package_name = _timestamp()."_${migration_name}";
    my %replace = _get_replacements($table, $data);

    my $target_path = "db/migrations/$package_name.pl";
    my $source_path = Migrate::Config::library_root."/templates/$action.tl";

    open(my $src, '<', $source_path) // die("Could not read template: $source_path\n");
    open(my $tgt, '>', $target_path) // die("Could not create migration: $target_path\n");

    while (defined(my $line = <$src>)) {
        $line =~ s/\{$_\}/$replace{$_}/g foreach (keys %replace);
        print $tgt $line;
    }

    return $target_path;
}

sub _get_replacements {
    my ($table_name, $data) = (shift // '', shift // {});
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
    my $datatypes = join('|', keys(%{ Migrate::Factory::class('datatype')->datatypes }));

    foreach (@column_data) {
        if ($_ eq 'not_null') { $options->{null} = 0 }
        elsif ($_ eq 'index') { $options->{index} = 1 }
        elsif ($_ eq 'unique') { $options->{index} = { unique => 1 } }
        else {
            my ($datatype, @props) = split(',', $_);
            _parse_column_datatype($options, $datatype, @props) if $datatype =~ /^(?:$datatypes)$/;
        }
    }

    return $options;
}

sub _parse_column_datatype {
    my $options = shift;
    my ($type, @props) = @_;
    $options->{type} = $type;
    if (@props) {
        $options->{limit} = $props[0] if scalar(@props) == 1;
        @$options{'precision', 'scale'} = @props if scalar(@props) > 1;
    }
}

# SERIALIZER
# Converts an array of column definition hashrefs to code lines for the generator

sub _serialize_timestamps {
    my $action = shift;
    my $table = shift;
    return 'timestamps' if _is_table_action($action);
    return qq[add_timestamps('$table')] if $action eq ADD;
    return qq[remove_timestamps('$table')];
}

sub _serialize_references { _serialize_columns(@_, 1) }

sub _serialize_columns {
    my $action = shift;
    my $table = shift;
    my $columns = shift // return ();
    my $is_ref = shift;
    return map { _serialize_column($action, $table, $_, $is_ref) // () } @$columns;
}

sub _serialize_column {
    my $action = shift;
    my $table = shift;
    my $options = shift;
    my $is_ref = shift;
    my ($column, $datatype, $options_str) = _get_column_attributes($options, $is_ref);
    return $is_ref
        ? _serialize_reference_method($action, $table, $column, $options_str)
        : _serialize_column_method($action, $table, $column, $datatype, $options_str);
}

sub _get_column_attributes {
    my $options = { %{ shift(@_) } };
    my $is_ref = shift;
    my $column = delete $options->{name} // die('Column name is required');
    my $datatype = delete $options->{type} // 'string';
    $options->{foreign_key} = 1 if $is_ref && Migrate::Config::config->{foreign_keys};
    return ($column, $datatype, _serialize_column_options($options));
}

sub _serialize_column_method {
    my $action = shift;
    my $table = shift;
    my $column = shift;
    my $datatype = shift;
    my $options = shift;
    return qq[$datatype('$column'$options)] if _is_table_action($action);
    return qq[remove_column('$table','$column')] if $action eq REMOVE;
    return qq[add_column('$table', '$column', '$datatype'$options)];
}

sub _serialize_reference_method {
    my $action = shift;
    my $table = shift;
    my $column = shift;
    my $options = shift;
    return qq[references('$column'$options)] if _is_table_action($action);
    return qq[remove_reference('$table','$column')] if $action eq REMOVE;
    return qq[add_reference('$table', '$column'$options)];
}

sub _serialize_column_options {
    my $options = shift // {};
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Sortkeys = 1;
    return scalar keys %$options? ', '.Dumper($options) : '';
}

sub _timestamp {
    my @time = gmtime();
    my @parts = reverse(@time[0..5]);
    $parts[0] += 1900;
    @time = map { sprintf("%02d", $_) } @parts;
    return join('', @time);
}

return 1;
