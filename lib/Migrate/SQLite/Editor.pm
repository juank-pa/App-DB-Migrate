package Migrate::SQLite::Editor;

use strict;
use warnings;

use Migrate::SQLite::Editor::Table;
use Migrate::SQLite::Editor::Index;
use Migrate::SQLite::Editor::Parser qw(parse_table parse_index);
use Migrate::Factory qw(id);
use Migrate::Dbh qw(get_dbh);

sub edit_table {
    my ($table_name) = @_;
    my $sql = _table_sql($table_name);
    my $table = parse_table($sql);
    $table->{indexes} = _table_indexes($table_name);
    return $table;
}

sub rename_index {
    my ($old_name, $new_name) = @_;
    die('not implemented');
    my $index = index_by_name($old_name);
    $index->rename($new_name);
    return ('DROP INDEX '.id($old_name), $index);
}

sub _table_sql {
    my $table = shift;
    my $sql = get_dbh->selectall_arrayref(qq{SELECT sql FROM sqlite_master WHERE type='table' AND tbl_name='$table'});
    my $res = $sql && $sql->[0] && $sql->[0]->[0];
    die("Could not find table $table") unless $res;
    return $res;
}

sub _table_indexes {
    my $table = shift;
    my $res = get_dbh->selectall_arrayref(qq{SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='$table'});
    die("Could not query table indexes for $table") unless $res;
    return [map { parse_index($_->[0]) } @{ $res }];
}

return 1;
