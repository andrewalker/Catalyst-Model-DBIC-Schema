package Catalyst::Model::DBIC::Schema::Role::Replicated;

use Moose::Role;
use Moose::Autobox;
use Carp::Clan '^Catalyst::Model::DBIC::Schema';

use Catalyst::Model::DBIC::Schema::Types 'ConnectInfos';

use namespace::clean -except => 'meta';

=head1 NAME

Catalyst::Model::DBIC::Schema::Role::Replicated - Replicated storage support for
L<Catalyst::Model::DBIC::Schema>

=head1 SYNOPSiS

    __PACKAGE__->config({
        roles => ['Replicated']
        connect_info => 
            ['dbi:mysql:master', 'user', 'pass'],
        replicants => [
            ['dbi:mysql:slave1', 'user', 'pass'],
            ['dbi:mysql:slave2', 'user', 'pass'],
            ['dbi:mysql:slave3', 'user', 'pass'],
        ]
    });

=head1 DESCRIPTION

B<DOES NOT WORK YET> -- requires some DBIC changes

Sets your storage_type to L<DBIx::Class::Storage::DBI::Replicated> and connects
replicants provided in config. See that module for supported resultset
attributes.

=head1 CONFIG PARAMETERS

=head2 replicants

Array of connect_info settings for every replicant.

=cut

has replicants => (
    is => 'ro', isa => ConnectInfos, coerce => 1, required => 1
);

after setup => sub {
    my $self = shift;

# check storage_type compatibility (if configured)
    if (my $storage_type = $self->storage_type) {
        my $class = $storage_type =~ /^::/ ?
            "DBIx::Class::Storage$storage_type"
            : $storage_type;

        croak "This storage_type cannot be used with replication"
            unless $class->isa('DBIx::Class::Storage::DBI::Replicated');
    } else {
        $self->storage_type('::DBI::Replicated');
    }
};

after finalize => sub {
    my $self = shift;

    $self->storage->connect_replicants($self->replicants->flatten);
};

=head1 SEE ALSO

L<Catalyst::Model::DBIC::Schema>, L<DBIx::Class>,
L<DBIx::Class::Storage::DBI::Replicated>,
L<Cache::FastMmap>, L<DBIx::Class::Cursor::Cached>

=head1 AUTHOR

Rafael Kitover, C<rkitover@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;