package Migrate::Status;

use strict;
use warnings;

use feature 'say';
use Dbh;

sub file_to_migration_description (_);

sub execute
{
    my @migrations = query_migrations();
    print_migrations(\@migrations);
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
    my $index = 0;
    my @files = get_migration_files();
    my @migrations = map { $_->{migration_id} } @{scalar(shift)};

    foreach my $file (@files) {
        $file =~s/\.pl$//;
        my $migration = shift @migrations;

        while ($migration && $migration lt $file) {
            say('[*]    '.file_to_migration_description($migration));
            $migration = shift @migrations;
        }

        if (!$migration || $file ne $migration) {
            print '[down] ';
            unshift(@migrations, $migration) if $migration;
        }
        else {
            print('[up]   ');
        }
        say(file_to_migration_description($file));
    }

    say('[*]    '.file_to_migration_description) foreach (@migrations);
}

sub file_to_migration_description (_)
{
    my $file = shift or return '';
    my @parts = split('_', $file);
    my $timestamp = shift(@parts);
    my $description = join(' ', @parts);
    return "$timestamp - \u$description";
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
