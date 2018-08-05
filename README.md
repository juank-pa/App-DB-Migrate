# Migrate

This library allows managing DB migrations using the command line. While there are other libraries out
there that achieve this, they either come bundled with ORMs and other larger frameworks, or are SQL based
making them DBMS dependant.

The inspiration behind Migrate was to create a migration system that simplifies the variety of DBMS SQL
language variations into a simple perl-based language that allows handling DB schema changes, without
removing the ability to write SQL commands for specific/advanced tasks completely.

The library uses a plugin paradigm allowing the creation of a plugin for any given DBI driver.

The command line tool can perform five different actions: `setup`, `status`, `generate`, `run` and `rollback`.

## The setup action

This is the first command action you'll have to execute before any other action. If you try to use other actions
before setting migrate up your receive a message prompting you to run setup first.

The setup command creates a `db` folder under the current directory. This `db` folder will contain the DB config
file as well as the migrations you'll generate with the [generate action](#the-generate-action). It will actually create two files:
`db/config.pl`, and `db/config.example.pl`. The `db/config.pl` file is properly excluded from a git repo using a 
`.gitignore` file.

You need to edit `db/config.pl` file to configure the database DSN and additional connection properties. The 
`db/config.example.pl` will be uploaded to your repo and will serve as a template for other developers to use as
their `db/config.pl` file.

Running the `setup` action again will have no effect. Nevertheless, running the `setup` action when only the
`db/config.pl` file is missing will use the existing `db/config.example.pl` as a template.

Syntax:

```bash
migrate setup
```

The standard configuration options are:

* **dsn:** The database DSN string as expected by the DBI library.
* **username:** The username used to connect to the database.
* **password:** The password used to connect to the database.
* **attr:** Additional DBI connection properties expected by the specific driver in use.
* **on_connect:** Is an anonymous function that will run immediately after a DB conection has been stablished. It
  receives the created `$dbh` object and will allow further customizations to the database connection.
* **id:** Is an anonymous function that receives a pluralized and singularized table name as parameters, and must return the primary key column name. This function is called prior to adding a primary key to a table to determine the column name. If the option is not provided then a primary key columns will be named `id`.
* **foreign_keys:** If set to true it will force the generation of foreign keys for reference columns. The default
  value is false. See the [generate action](#the-generate-action) documentation for further info.
* **add_options:** If set to true it will add additional SQL options after a CREATE TABLE definition as specified by
  the `create_table` method `options` key. If false, table options will be ignored and will not be added to the
  generated SQL command. The default value is false. For more information see the `create_table` method documentation.

Additional configuration options can be available depending on the migrate plugin implementation.

## The generate action

Once the DB connection is setup correctly you can start creating migrations. The `generate` action will allow
you to do just that. The basic syntax will receive a (`--name`or `-n`) parameter and will generate a perl file
under the `db/migrations` containing an `up` and `down` functions you'll use to add your migration code.

```bash
migrate generate -n my_migration_name
```

The above example generates a migration file named *YYYYMMDDhhmmss_my_migration.pl* were *YYYYMMDDhhmmss* refers
to the current timestamp followed by the name you specified. The command prints the path of the newly generated file.

You can further modify the generated perl file to perform additional actions or detail you migration even more. The `up`
and `down` functions receive two parameters: the migrate handler object `$mh` that provides an API to modify the
database, and a DBI database handler `$dbh` that will allow running custom/advanced SQL commands or even query existing
data so you can migrate the current data to a new format as well. For detailed documentation on the handler API read the
wiki [migrate handler page](https://github.com/juank-pa/Perl-Migrate/wiki/The-Migrate-API).

### The name IS important!
A command like the previous one generates a file based on a generic template, and you'll have to write your migration
code completely from scratch. But there are certain migration *magic* names that will use other helpful templates.

* **create_<table_name>:** This migration will use a template prepopulated with a `create_table` statement and will use
  the rest of the migration name as the table name to create.
* **add_<column_name>\_to\_<table_name>:** This migration will use a template prepopulated with an `add_column` statement
  and will use the rest of the migration name as the column and table names correspondingly.
* **drop_<table_name>:** This migration will use a template prepopulated with a `drop_table` statement and will use
  the rest of the migration name as the table name to drop.
* **remove_<column_name>\_from\_<table_name>:** This migration will use a template prepopulated with a `remove_column`
  statement and will use the rest of the migration name as the column and table names correspondingly.

All magic names will also add the corresponding `down` actions. Additionally, every magic name can receive further
options so that they can prepopulate more than just the table name. Take into account the generated files are just
templates which can be further customized later.

### The --column or -c option

The `-c` option adds a column to a `create_..` or `drop_...` migration and allows better specifying column properties
for `add_..._to_...` or `remove_..._from_...`. This option has the following syntax:

```bash
-c column_name[:datatype][:not_null][:index|:unique]
```

Available column properties are:

* **datatype:** The list of available datatypes can vary for each Driver implementation but at the bare minimum all drivers
  implement: `string`, `char`, `text`, `integer`, `bigint`, `float`, `decimal`, `numeric`, `date`, `time`, `datetime`, 
  `binary` and `boolean`. These types map to specific driver SQL datatypes e.g. `string` maps to `CHARVAR` on most DBMSs.
  Datatypes can add comma separated size and precision attributes e.g. `float,20,3`. If datatype is not specified `string`
  is used by default.
* **not_null:** They specify a column as being NOT NULL.
* **index or unique:** They specify whether to add a index or a unique index to the column. No index is added otherwise.

You can add as many columns as you desire by using the `-c` option many times.

Example:

```bash
migrate generate -n create_employee -c name:string,60:not_null -c age:integer:index -c email:unique
```

### The --ref or -r option

The `-r` option is very similar to the `-c` option but generates a reference column instead. The generated SQL column
name will be `<column_name>_id`, with an `integer` datatype by default. All this can be further customized if desired
by editing the generated migration file (do not add the `_id` suffix). This option has the following syntax:

```bash
-r column_name[:datatype][:not_null][:index]
```

Refer to the [`-c` option](#the---column-or--c-option) to get more information on the properties.

References do not create foreign keys by default. To force this, simply add the `{ foreign_key => 1 }` options to the 
generated column code or setup the `foreign_keys` key in the `db/config.pl` file (see the [setup action](#the-setup-action)). 
The foreign key will reference the `id` column of a `<plural_column_name>` table by default but this can be further
customized as well.

### The --tstamps or -t option

This options adds a timestamps method call that will ultimately create a `created_at` and `updated_at` columns to the
table. This columns use the `datetime` datatype.

## The status action

The status action will print a list of all known migrations. Every migration shows a status, the
migration timestamp and its user friendly name.

The status can be any of the following:
* **[up]** Means the migration has already been applied to the database.
* **[down]** Means the migration has not been already applied to the database.
* **[\*]** Means there exists a migration registered in the database that doesn't have a corresponding
  file in the migration folder.

If instead of printing a user friendly migration name you prefer a file path use the `--file` or `-f` option.

## The run action
Once we have our migrations in place is time to run them. Use the run action to execute all the migrations that have not been yet executed. You'll get a report of all the SQL statements that ran successfully. Every migration is executed as a transaction so if you get a failure in the middle of a migration the whole migration will be cancelled altogether and a report of the error will be printed to the console.

Syntax:
```bash
migrate run
```

## The rollback action
If you need to undo the last ran migration you can use the rollback action. The rollback action will only undo one migration at a time. If you want to undo more than one migration use the `--steps` or `-s` option specifying the amount of migrations to undo.

Syntax:
```bash
migrate rollback
```
