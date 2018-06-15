# Perl:Migrate (WIP)
**Note:** This is a work in progress. Not even a MVP status is yet achieved.

This library allows managing DB migrations with the command line. I was mostly inspired in
the Ruby on Rails migration system. While there are other libraries out there that achieve this, they
come bundled with ORMs and other larger frameworks. I needed something minimal that could be used
independently (regardless of other framewors you might use) and that it was as simple to install
in systems with restricted access.

MVP will start handling SQL commands directly trying to be as generic as possible but I'll try to
make it in such a way we could support the most common DBMs out there.

## Current limitations
1. I just started supporting Informix DB which I'm using at the time. I pretend to write adapters for
   the most common DBMSs.
2. The first MVP will be SQL based so it will be somewhat limiting and a bit less readable. After that I
   plan to support a programmatic API that will handle db creation and manipulation.

## Setup
This command requires access to a DBMS to allow running the migrations into it and to store migration
tracking information.

To setup the command you'll need to export the following environment variables with the information
required to connect to the DBMS:

```bash
MS_DBSchema=<db_scema>
MS_DBName=<db_name>
MS_DBUserName=<db_user_name>
MS_DBPassword=<db_user_password>
MS_DBDataSource=<db_data_source>
```

## The Perl migrate.pl command
The `migrate.pl` command won't do anything by itself, you should call it passing an additional action to perform.
Valid actions are `generate`, `run`, `rollback` and `status`.

### The Generate command
The generate command allows generating a perl module with two subroutines "up" and "down". Up will
execute the SQL and down will have rollback commands. The only mandatory option is `-n` to specify the
name of the migration:

```bash
migrate.pl generate -n my_migration
```

The above example will create a `migrations` folder under the current folder and will also create a file
named *YYYYMMDDhhmmss_my_migration.pl* with a small template that will let you just add your SQL command.
*YYYYMMDDhhmmss* refers to the current timestamp.

#### The name IS important!
If you use a command like the previous one a generic template will be created, and you'll have to
write your SQL from scratch. But there are certain name prefixes that will create other helpful templates.

#### create_table_<singular_table_name>
This prefix will create a template prepopulated with a `CREATE TABLE` (and the corresponding `DROP TABLE` in down)
SQL command and will use the rest of the command as the table name in the SQL. The table name must be in singular 
form (this is important). The template will also add a primary key based on the table name.

You can also add columns from the same command line by using the `-c [columns]` option. Where columns is a comma 
separated list of column names for you table. e.g. `-c age,name`. The columns option can have the following format:

```bash
-c column_name[:datatype][:not_null][,...other_columns]
```

Additional colon separated column attributes can be placed in any order as long as the column name is always first.
If `datatype`is not specified then `VARCHAR` is used.

The `-r [singular_table_names]` option is very similar to the columns option but instead of receiving column names
it receives other table names in singular form to create references (foreign keys) to those tables. You can use the
same attributes as you do with the `-c` option. If `datatype`is not specified `INTEGER` is used.

When adding references, the corresponding foreign key constraint operations will be added for up and down.

```bash
-r singular_table_name[:datatype][:not_null][,...other_table_names]
```

To be continued...
