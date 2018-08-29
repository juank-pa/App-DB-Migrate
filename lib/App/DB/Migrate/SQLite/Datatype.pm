package App::DB::Migrate::SQLite::Datatype;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Datatype);

sub datatypes {
    {
        string      => 'VARCHAR',
        char        => 'CHARACTER',
        text        => 'TEXT',
        integer     => 'INTEGER',
        bigint      => 'BIGINT',
        float       => 'FLOAT',
        decimal     => 'DECIMAL',
        numeric     => 'NUMERIC',
        date        => 'DATE',
        time        => 'TIME',
        datetime    => 'DATETIME',
        binary      => 'BLOB',
        boolean     => 'BOOLEAN',
    }
}

return 1;
