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
MS_SCHEMA=<db_scema>
MS_USER=<db_user_name>
MS_PASS=<db_user_password>
MS_DSN=<db_data_source>
```

The DSN must be formated as expected by DBI: `dbi:<Driver>:...`

## The Perl migrate command
The `migrate` command won't do anything by itself, you should call it passing an additional action to perform.
Valid actions are `generate`, `run`, `rollback` and `status`.

### The generate command
The generate command allows generating a perl module with two subroutines `up` and `down`. Up will
execute commands to perform the migration while down will have rollback commands.
The only mandatory option is `-n` to specify the name of the migration:

```bash
migrate generate -n my_migration_name
```

The above example generates a `migrations` folder under the current folder and will also create a file
named *YYYYMMDDhhmmss_my_migration.pl* were *YYYYMMDDhhmmss* refers to the current timestamp. The command
prints the path of the newly generated file.

#### The name IS important!
If you use a command like the previous one a generic template will be created, and you'll have to
write your migration from scratch. But there are certain migration names that will create other helpful templates.

#### create_table_<singular_table_name>
This prefix will create a template prepopulated with a `create_table` (and the corresponding `drop_table` in down)
command and will use the rest of the migration name as the table name. The table name must be in singular form
(this is important).

*The -c option*

You can add columns from the same command line by using the `-c [columns]` option. Where columns is a quoted space
separated list of column for you table. e.g. `-c 'age name'`. This option has the following syntax:

```bash
-c 'column_name[:datatype[(s,...)]][:not_null|:null][:index|:unique][ ...more_columns]'
```

Additional colon separated column properties can be added for each column in any order as long as the column name is
always first. Available column properties are:

* *datatype:* available datatypes are: `string`, `char`, `text`, `integer`, `float`, `decimal`, `date`, and `datetime`.
  These types map to SQL types depending on the driver e.g. `string` maps to `CHARVAR` on most DBMS. Datatypes can
  receive size and precision attributes in parenthesis e.g. `integer(20)`. If datatype is not specified `string` is used
  by default.
* *not_null or null:* They specify whether the column is `null` or `not_null`. If not specified `null` is used.
* *index or unique:* They specify whether to add a index or a unique index to the column. No index is added otherwise.

Example:

```bash
migrate generate -n create_table_employee -c 'name:string:not_null age:integer:index email:unique'
```

*The -r option*

The `-r [singular_table_names]` option is very similar to the columns option but instead of receiving column names
it receives table names in singular form to create references (foreign keys) to those tables. You can use the
same column properties you use for the `-c` option. If `datatype` is not specified `integer` is used by default.
This option has the following syntax:

```bash
-r 'singular_table_name[:datatype[(s,...)]][:not_null|:null][:index|:unique][ ...more_table_names]'
```

### The status command

The status command will print a list of all known migrations. Every migration shows a status, the
migration timestamp and its user friendly name.

The status can be any of the following:
* [up] Means the migration has already been applied to the database.
* [down] Means the migration has not been already applied to the database.
* [*] Means there exists a migration registered in the database that doesn't have a corresponding
  file in the migration folder.

If instead of printing a user friendly migration name you prefer a file path use the `-f` option.

To be continued...
