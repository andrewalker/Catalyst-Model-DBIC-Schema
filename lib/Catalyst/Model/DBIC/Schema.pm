package Catalyst::Model::DBIC::Schema;

use strict;
use warnings;
no warnings 'uninitialized';

our $VERSION = '0.24';

use parent qw/Catalyst::Model Class::Accessor::Fast Class::Data::Accessor/;
use MRO::Compat;
use mro 'c3';
use UNIVERSAL::require;
use Carp;
use Data::Dumper;
use DBIx::Class ();
use Scalar::Util 'reftype';
use namespace::clean -except => 'meta';

__PACKAGE__->mk_classaccessor('composed_schema');
__PACKAGE__->mk_accessors(qw/
    schema connect_info schema_class storage_type caching model_name
/);

=head1 NAME

Catalyst::Model::DBIC::Schema - DBIx::Class::Schema Model Class

=head1 SYNOPSIS

Manual creation of a DBIx::Class::Schema and a Catalyst::Model::DBIC::Schema:

=over

=item 1.

Create the DBIx:Class schema in MyApp/Schema/FilmDB.pm:

  package MyApp::Schema::FilmDB;
  use base qw/DBIx::Class::Schema/;

  __PACKAGE__->load_classes(qw/Actor Role/);

=item 2.

Create some classes for the tables in the database, for example an 
Actor in MyApp/Schema/FilmDB/Actor.pm:

  package MyApp::Schema::FilmDB::Actor;
  use base qw/DBIx::Class/

  __PACKAGE__->load_components(qw/Core/);
  __PACKAGE__->table('actor');

  ...

and a Role in MyApp/Schema/FilmDB/Role.pm:

  package MyApp::Schema::FilmDB::Role;
  use base qw/DBIx::Class/

  __PACKAGE__->load_components(qw/Core/);
  __PACKAGE__->table('role');

  ...    

Notice that the schema is in MyApp::Schema, not in MyApp::Model. This way it's 
usable as a standalone module and you can test/run it without Catalyst. 

=item 3.

To expose it to Catalyst as a model, you should create a DBIC Model in
MyApp/Model/FilmDB.pm:

  package MyApp::Model::FilmDB;
  use base qw/Catalyst::Model::DBIC::Schema/;

  __PACKAGE__->config(
      schema_class => 'MyApp::Schema::FilmDB',
      connect_info => {
                        dsn => "DBI:...",
                        user => "username",
                        password => "password",
                      }
  );

See below for a full list of the possible config parameters.

=back

Now you have a working Model which accesses your separate DBIC Schema. This can
be used/accessed in the normal Catalyst manner, via $c->model():

  my $actor = $c->model('FilmDB::Actor')->find(1);

You can also use it to set up DBIC authentication with 
Authentication::Store::DBIC in MyApp.pm:

  package MyApp;

  use Catalyst qw/... Authentication::Store::DBIC/;

  ...

  __PACKAGE__->config->{authentication}{dbic} = {
      user_class      => 'FilmDB::Actor',
      user_field      => 'name',
      password_field  => 'password'
  }

C<< $c->model('Schema::Source') >> returns a L<DBIx::Class::ResultSet> for 
the source name parameter passed. To find out more about which methods can 
be called on a ResultSet, or how to add your own methods to it, please see 
the ResultSet documentation in the L<DBIx::Class> distribution.

Some examples are given below:

  # to access schema methods directly:
  $c->model('FilmDB')->schema->source(...);

  # to access the source object, resultset, and class:
  $c->model('FilmDB')->source(...);
  $c->model('FilmDB')->resultset(...);
  $c->model('FilmDB')->class(...);

  # For resultsets, there's an even quicker shortcut:
  $c->model('FilmDB::Actor')
  # is the same as $c->model('FilmDB')->resultset('Actor')

  # To get the composed schema for making new connections:
  my $newconn = $c->model('FilmDB')->composed_schema->connect(...);

  # Or the same thing via a convenience shortcut:
  my $newconn = $c->model('FilmDB')->connect(...);

  # or, if your schema works on different storage drivers:
  my $newconn = $c->model('FilmDB')->composed_schema->clone();
  $newconn->storage_type('::LDAP');
  $newconn->connection(...);

  # and again, a convenience shortcut
  my $newconn = $c->model('FilmDB')->clone();
  $newconn->storage_type('::LDAP');
  $newconn->connection(...);

=head1 DESCRIPTION

This is a Catalyst Model for L<DBIx::Class::Schema>-based Models.  See
the documentation for L<Catalyst::Helper::Model::DBIC::Schema> for
information on generating these Models via Helper scripts.

When your Catalyst app starts up, a thin Model layer is created as an 
interface to your DBIC Schema. It should be clearly noted that the model 
object returned by C<< $c->model('FilmDB') >> is NOT itself a DBIC schema or 
resultset object, but merely a wrapper proving L<methods|/METHODS> to access 
the underlying schema. 

In addition to this model class, a shortcut class is generated for each 
source in the schema, allowing easy and direct access to a resultset of the 
corresponding type. These generated classes are even thinner than the model 
class, providing no public methods but simply hooking into Catalyst's 
model() accessor via the 
L<ACCEPT_CONTEXT|Catalyst::Component/ACCEPT_CONTEXT> mechanism. The complete 
contents of each generated class is roughly equivalent to the following:

  package MyApp::Model::FilmDB::Actor
  sub ACCEPT_CONTEXT {
      my ($self, $c) = @_;
      $c->model('FilmDB')->resultset('Actor');
  }

In short, there are three techniques available for obtaining a DBIC 
resultset object: 

  # the long way
  my $rs = $c->model('FilmDB')->schema->resultset('Actor');

  # using the shortcut method on the model object
  my $rs = $c->model('FilmDB')->resultset('Actor');

  # using the generated class directly
  my $rs = $c->model('FilmDB::Actor');

In order to add methods to a DBIC resultset, you cannot simply add them to 
the source (row, table) definition class; you must define a separate custom 
resultset class. See L<DBIx::Class::Manual::Cookbook/"Predefined searches"> 
for more info.

=head1 CONFIG PARAMETERS

=over 4

=item schema_class

This is the classname of your L<DBIx::Class::Schema> Schema.  It needs
to be findable in C<@INC>, but it does not need to be inside the 
C<Catalyst::Model::> namespace.  This parameter is required.

=item connect_info

This is an arrayref of connection parameters, which are specific to your
C<storage_type> (see your storage type documentation for more details). 
If you only need one parameter (e.g. the DSN), you can just pass a string 
instead of an arrayref.

This is not required if C<schema_class> already has connection information
defined inside itself (which isn't highly recommended, but can be done)

For L<DBIx::Class::Storage::DBI>, which is the only supported
C<storage_type> in L<DBIx::Class> at the time of this writing, the
parameters are your dsn, username, password, and connect options hashref.

See L<DBIx::Class::Storage::DBI/connect_info> for a detailed explanation
of the arguments supported.

Examples:

  connect_info => {
    dsn => 'dbi:Pg:dbname=mypgdb',
    user => 'postgres',
    password => ''
  }

  connect_info => {
    dsn => 'dbi:SQLite:dbname=foo.db',
    on_connect_do => [
      'PRAGMA synchronous = OFF',
    ]
  }

  connect_info => {
    dsn => 'dbi:Pg:dbname=mypgdb',
    user => 'postgres',
    password => '',
    pg_enable_utf8 => 1,
    on_connect_do => [
      'some SQL statement',
      'another SQL statement',
    ],
  }

Or using L<Config::General>:

    <Model::FilmDB>
        schema_class   MyApp::Schema::FilmDB
        <connect_info>
            dsn   dbi:Pg:dbname=mypgdb
            user   postgres
            password ''
            auto_savepoint 1
            on_connect_do   some SQL statement
            on_connect_do   another SQL statement
        </connect_info>
    </Model::FilmDB>

or

    <Model::FilmDB>
        schema_class   MyApp::Schema::FilmDB
        connect_info   dbi:SQLite:dbname=foo.db
    </Model::FilmDB>

Or using L<YAML>:

  Model::MyDB:
      schema_class: MyDB
      connect_info:
          dsn: dbi:Oracle:mydb
          user: mtfnpy
          password: mypass
          LongReadLen: 1000000
          LongTruncOk: 1
          on_connect_do: [ "alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS'" ]
          cursor_class: 'DBIx::Class::Cursor::Cached'

The old arrayref style with hashrefs for L<DBI> then L<DBIx::Class> options is also
supported:

  connect_info => [
    'dbi:Pg:dbname=mypgdb',
    'postgres',
    '',
    {
      pg_enable_utf8 => 1,
    },
    {
      on_connect_do => [
        'some SQL statement',
        'another SQL statement',
      ],
    }
  ]

=item caching

Whether or not to enable caching support using L<DBIx::Class::Cursor::Cached>
and L<Catalyst::Plugin::Cache>. Enabled by default.

In order for this to work, L<Catalyst::Plugin::Cache> must be configured and
loaded. A possible configuration would look like this:

  <Plugin::Cache>
    <backend>       
      class Cache::FastMmap
      unlink_on_exit 1
    </backend>
  </Plugin::Cache>

Then in your queries, set the C<cache_for> ResultSet attribute to the number of
seconds you want the query results to be cached for, eg.:

  $c->model('DB::Table')->search({ foo => 'bar' }, { cache_for => 18000 });

=item storage_type

Allows the use of a different C<storage_type> than what is set in your
C<schema_class> (which in turn defaults to C<::DBI> if not set in current
L<DBIx::Class>).  Completely optional, and probably unnecessary for most
people until other storage backends become available for L<DBIx::Class>.

=back

=head1 METHODS

=over 4

=item new

Instantiates the Model based on the above-documented ->config parameters.
The only required parameter is C<schema_class>.  C<connect_info> is
required in the case that C<schema_class> does not already have connection
information defined for it.

=item schema

Accessor which returns the connected schema being used by the this model.
There are direct shortcuts on the model class itself for
schema->resultset, schema->source, and schema->class.

=item composed_schema

Accessor which returns the composed schema, which has no connection info,
which was used in constructing the C<schema> above.  Useful for creating
new connections based on the same schema/model.  There are direct shortcuts
from the model object for composed_schema->clone and composed_schema->connect

=item clone

Shortcut for ->composed_schema->clone

=item connect

Shortcut for ->composed_schema->connect

=item source

Shortcut for ->schema->source

=item class

Shortcut for ->schema->class

=item resultset

Shortcut for ->schema->resultset

=item storage

Provides an accessor for the connected schema's storage object.
Used often for debugging and controlling transactions.

=cut

sub new {
    my $self = shift->next::method(@_);
    
    my $class = ref $self;

    $self->_build_model_name;

    croak "->config->{schema_class} must be defined for this model"
        unless $self->schema_class;

    my $schema_class = $self->schema_class;

    $schema_class->require
        or croak "Cannot load schema class '$schema_class': $@";

    if( !$self->connect_info ) {
        if($schema_class->storage && $schema_class->storage->connect_info) {
            $self->connect_info($schema_class->storage->connect_info);
        }
        else {
            croak "Either ->config->{connect_info} must be defined for $class"
                  . " or $schema_class must have connect info defined on it."
		  . " Here's what we got:\n"
		  . Dumper($self);
        }
    }

    $self->composed_schema($schema_class->compose_namespace($class));

    $self->schema($self->composed_schema->clone);

    $self->schema->storage_type($self->storage_type)
        if $self->storage_type;

    $self->_normalize_connect_info;

    $self->_setup_caching;

    $self->schema->connection($self->connect_info);

    $self->_install_rs_models;

    return $self;
}

sub clone { shift->composed_schema->clone(@_); }

sub connect { shift->composed_schema->connect(@_); }

sub storage { shift->schema->storage(@_); }

=item ACCEPT_CONTEXT

Sets up runtime cache support on $c->model invocation.

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;

    return $self unless 
        $self->caching;
    
    unless ($c->can('cache') && ref $c->cache) {
        $c->log->debug("DBIx::Class cursor caching disabled, you don't seem to"
            . " have a working Cache plugin.");
        $self->caching(0);
        $self->_reset_cursor_class;
        return $self;
    }

    if (ref $self->schema->default_resultset_attributes) {
        $self->schema->default_resultset_attributes->{cache_object} =
            $c->cache;
    } else {
        $self->schema->default_resultset_attributes({
            cache_object => $c->cache
        });
    }

    $self;
}

sub _normalize_connect_info {
    my $self = shift;

    my $connect_info = $self->connect_info;

    my @connect_info = reftype $connect_info eq 'ARRAY' ?
        @$connect_info : $connect_info;

    my %connect_info;

    if (!ref $connect_info[0]) { # array style
        @connect_info{qw/dsn user password/} =
            splice @connect_info, 0, 3;

        for my $i (0..1) {
            my $extra = shift @connect_info;
            last unless $extra;
            croak "invalid connect_info" unless reftype $extra eq 'HASH';

            %connect_info = (%connect_info, %$extra);
        }

        croak "invalid connect_info" if @connect_info;
    } elsif (@connect_info == 1 && reftype $connect_info[0] eq 'HASH') {
        %connect_info = %{ $connect_info[0] };
    } elsif (reftype $connect_info eq 'HASH') {
        %connect_info = %$connect_info;
    } else {
        croak "invalid connect_info";
    }

    if (exists $connect_info{cursor_class}) {
        $connect_info{cursor_class}->require
            or croak "invalid connect_info: Cannot load your cursor_class"
                     . " $connect_info{cursor_class}: $@";
    }

    $self->connect_info(\%connect_info);
}

sub _install_rs_models {
    my $self  = shift;
    my $class = ref $self;

    no strict 'refs';
    foreach my $moniker ($self->schema->sources) {
        my $classname = "${class}::$moniker";
        *{"${classname}::ACCEPT_CONTEXT"} = sub {
            shift;
            shift->model($self->model_name)->resultset($moniker);
        }
    }
}

sub _build_model_name {
    my $self = shift;

    my $class = ref $self;
    my $model_name = $class;
    $model_name =~ s/^[\w:]+::(?:Model|M):://;

    $self->model_name($model_name);
}

sub _setup_caching {
    my $self = shift;

    return if defined $self->caching && !$self->caching;

    $self->caching(0);

    if (my $cursor_class = $self->connect_info->{cursor_class}) {
        unless ($cursor_class->can('clear_cache')) {
            carp "Caching disabled, cursor_class $cursor_class does not"
                 . " support it.";
            return;
        }
    } else {
        my $cursor_class = 'DBIx::Class::Cursor::Cached';

        unless ($cursor_class->require) {
            carp "Caching disabled, cannot load $cursor_class: $@";
            return;
        }

        $self->connect_info->{cursor_class} = $cursor_class;
    }

    $self->caching(1);

    1;
}

sub _reset_cursor_class {
    my $self = shift;

    if ($self->connect_info->{cursor_class} eq 'DBIx::Class::Cursor::Cached') {
        $self->storage->cursor_class('DBIx::Class::Storage::DBI::Cursor');
    }
    
    1;
}

=back

=head1 SEE ALSO

General Catalyst Stuff:

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst::Helper>, L<Catalyst>,

Stuff related to DBIC and this Model style:

L<DBIx::Class>, L<DBIx::Class::Schema>,
L<DBIx::Class::Schema::Loader>, L<Catalyst::Helper::Model::DBIC::Schema>

=head1 AUTHOR

Brandon L Black, C<blblack@gmail.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
