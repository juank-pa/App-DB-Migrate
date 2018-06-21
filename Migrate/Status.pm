package Migrate::Status;

use strict;
use warnings;

use feature 'say';
use Dbh;

sub print_migration ($_);

sub execute
{
    my $options = shift;
    print_migrations(exists $options->{f});
}

sub query_migrations
{
    my $query = <<EOF;
SELECT * FROM "$Dbh::DBSchema"._migrations ORDER BY migration_id;
EOF
    my $dbh = Dbh::getDBH();
    return Dbh::runSQL($query, undef, $dbh);
}

sub print_migrations
{
    my $filenames = shift // 0;
    my @migrations = get_migrations();
    print_migration($filenames) foreach @migrations;
}

sub print_migration ($_)
{
    my $filenames = shift // 0;
    my $migration = shift;
    my $description = $filenames? $migration->{path} : migration_description($migration);
    printf("%-7s%s\n", "[$migration->{status}]", $description);
}

sub get_migrations
{
    my $index = 0;
    my @files = get_migration_files();
    my @migrations = map { $_->{migration_id} } (query_migrations);
    my @results;

    foreach my $file (@files) {
        $file =~ s/\.pl$//;
        my $migration = shift @migrations;

        while ($migration && $migration lt $file) {
            push(@results, get_migration_data($migration, '*'));
            $migration = shift @migrations;
        }

        if (!$migration || $file ne $migration) {
            push(@results, get_migration_data($file, 'down'));
            unshift(@migrations, $migration) if $migration;
        }
        else {
            push(@results, get_migration_data($migration, 'up'));
        }
    }

    push(@results, get_migration_data($_, '*')) foreach (@migrations);
    return @results;
}

sub get_migration_data
{
    my $migration_id = shift;
    my $status = shift;
    return {
        id => $migration_id,
        package => "_$migration_id",
        path => "migrations/$migration_id.pl",
        status => $status
    };
}

sub migration_description
{
    my $migration = shift or return '';
    my $id = $migration->{id};
    my @parts = split('_', $id);
    my $timestamp = shift(@parts);
    my $description = join(' ', @parts);
    return "$timestamp \u$description";
}

sub get_migration_files
{
    my $directory = './migrations';
    opendir (DIR, $directory) or die 'There is no migrations folder';
    my @files = sort(readdir DIR);
    close DIR;
    return @files[2..$#files];
}

return 1;