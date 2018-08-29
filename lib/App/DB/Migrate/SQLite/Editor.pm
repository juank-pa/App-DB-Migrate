package App::DB::Migrate::SQLite::Editor;

use strict;
use warnings;

use App::DB::Migrate::SQLite::Editor::Parser qw(parse_table parse_index);
use App::DB::Migrate::Factory qw(id);
use App::DB::Migrate::Dbh qw(get_dbh);

sub edit_table {
    my $table_name = shift;
    my $dbh = shift // get_dbh();
    my $sql = _table_sql($table_name, $dbh);
    my $table = parse_table($sql);
    $table->set_indexes(_table_indexes($table_name, $dbh));
    return $table;
}

sub rename_index {
    my $old_name = shift || die('Old index name needed');
    my $new_name = shift || die('New index name needed');
    my $dbh = shift // get_dbh();
    my $index = index_by_name($old_name, $dbh);
    $index->rename($new_name);
    return ('DROP INDEX '.id($old_name), $index);
}

sub index_by_name {
    my $index = shift || die('Index name needed');
    my $dbh = shift // get_dbh();
    my $sql = $dbh->selectall_arrayref(
        "SELECT sql FROM sqlite_master WHERE type='index' AND name=?",
        undef, $index
    ) // die("Error querying for index $index\n$@");
    die("Could not find index $index") unless $sql->[0]->[0];
    return parse_index($sql->[0]->[0]);
}

sub _table_sql {
    my $table = shift;
    my $dbh = shift // get_dbh();
    my $sql = $dbh->selectall_arrayref(
        "SELECT sql FROM sqlite_master WHERE type='table' AND tbl_name=?",
        undef, $table
    ) // die("Error querying for table $table\n$@");
    die("Could not find table $table") unless $sql->[0]->[0];
    return $sql->[0]->[0];
}

sub _table_indexes {
    my $table = shift;
    my $dbh = shift // get_dbh();
    my $res = $dbh->selectall_arrayref(
        "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=?",
        undef, $table
    ) // die("Error querying indexes for table $table\n$@");
    return map { $_->[0]? parse_index($_->[0]) : () } @{ $res };
}

return 1;
