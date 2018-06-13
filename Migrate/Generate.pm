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
        when ($name =~ s/^create_table_// > 0) { generate_create_table($name) }
        when ($name =~ s/^drop_table_// > 0) { generate_drop_table($name) }
        when ($name =~ s/^add_column_// > 0) { generate_add_column($name) }
        when ($name =~ s/^drop_column_// > 0) { generate_add_column($name) }
        default { generate_generic($name) }
    }
}

sub generate_file
{
    my ($action, $subject, $table_name, $columns) = (shift, shift, shift, shift);

    my $package_name = getTimestamp()."_${action}_${subject}";
    my $target_filename = "migrations/$package_name.pl";
    my %replace = getReplacements($package_name, $table_name, $columns);

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
    my ($package_name, $table_name, $columns) = (shift, shift, shift // '');
    my $pk = "${table_name}_id";
    $columns = "  ${pk} serial";
    return (
        'PACKAGE_NAME' => $package_name,
        'DBSCHEMA' => $Dbh::DBSchema,
        'DBTABLENAME' => plural($table_name),
        'DBTABLEPK' => $pk,
        'DBCOLUMNS' => $columns,
    );
}

sub generate_create_table
{
    my $table_name = shift;
    generate_file('create_table', $table_name, $table_name, '');
}

sub generate_drop_table
{
}

sub generate_add_column
{
}

sub generate_drop_column
{
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
