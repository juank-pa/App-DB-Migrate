package Migrate::SQLite::Editor;

use strict;
use warnings;

use Migrate::SQLite::Editor::Table;
use Migrate::SQLite::Editor::Index;
use Migrate::SQLite::Editor::Parser qw(parse_table);

sub edit_table {
    my ($table_name) = @_;
    my $sql = _table_sql($table_name);
    my $table = parse_table($sql);
    $table->{indexes} = _table_indexes($table_name);
    return $table;
}

sub rename_index {
    my ($old_name, $new_name) = @_;
    my $index = index_by_name($old_name);
    $index->rename($new_name);
    return (qq{DROP INDEX "$old_name"}, $index);
}

sub index_by_name {
    my $name = shift;
    return Migrate::SQLite::Editor::Index->new(qq{CREATE INDEX "$name" ON "artists" (name)});
}

sub _table_sql { qq{CREATE TABLE "mytable" (id INTEGER CONSTRAINT "pk_tracks""'id" PRIMARY KEY AUTOINCREMENT NOT NULL,"name" VARCHAR(120) NOT NULL DEFAULT '',composer NOT NULL,unit_price VARCHAR DEFAULT "",album_id INTEGER CONSTRAINT "fk_tracks_album_id" REFERENCES albums (id),media_type_id INTEGER CONSTRAINT "fk_tracks_media_type_id" REFERENCES media_types (id) DEFAULT 88,genre_id INTEGER, milliseconds INTEGER, test float(1,2), created_at DATETIME) WITHOUT ROWID} }

sub _table_indexes {
    [
        Migrate::SQLite::Editor::Index->new(qq{CREATE INDEX "idx_artists_name" ON "artists" (name)}),
        Migrate::SQLite::Editor::Index->new(qq{CREATE INDEX "idx_artists_composer" ON "artists" (composer)}),
        Migrate::SQLite::Editor::Index->new(qq{CREATE INDEX "idx_artists_composer" ON "artists" (name DESC, composer ASC)}),
    ]
}

return 1;
