package Otogiri::Plugin::BulkInsert;
use 5.008005;
use strict;
use warnings;

our $VERSION = "0.02";
our @EXPORT = qw(bulk_insert);

sub bulk_insert {
    my ($self, $table, $args, $opt) = @_;

    my $dbh = $self->dbh;
    my $can_use_sql_maker = $dbh->{Driver}->{Name} eq 'mysql' ? 1
                          : $dbh->{Driver}->{Name} eq 'Pg' && $dbh->{pg_server_version} >= 82000 ;

    if ( ref $opt eq 'ARRAY' && ref $opt->[0] eq 'HASH' ) {
        $can_use_sql_maker = undef;
    }

    if ( $can_use_sql_maker ) {
        Otogiri::Plugin::BulkInsert::_bulk_insert_using_sql_maker($self, $table, $args, $opt);
    }
    else {
        Otogiri::Plugin::BulkInsert::_bulk_insert_plain($self, $table, $args, $opt);
    }
}

sub _bulk_insert_using_sql_maker {
    my ($self, $table, $args, $opt) = @_;

    SQL::Maker->load_plugin('InsertMulti');
    my ($sql, @binds) = $self->maker->insert_multi($table, $args, $opt);
    $self->do($sql, @binds);
}

sub _bulk_insert_plain {
    my ($self, $table, $key_list, $row_list) = @_;

    my $keys = join(', ', @$key_list);
    my $binds = join(', ', map {'?'} @$key_list);

    my $sql = sprintf('INSERT INTO %s (%s) VALUES (%s)', $table, $keys, $binds);
    my $sth = $self->dbh->prepare($sql);

    my $txn = $self->txn_scope();

    for my $row (@$row_list) {
        my %rowdata = %$row;
        $sth->execute(@rowdata{@$key_list});
    }

    $txn->commit();
    $sth->finish;
}

1;
__END__

=encoding utf-8

=head1 NAME

Otogiri::Plugin::BulkInsert - bulk insert for Otogiri

=head1 SYNOPSIS

    use Otogiri;
    use Otogiri::Plugin;
    
    my $otogiri = Otogiri->new(...);
    $otogiri->load_plugin('BulkInsert');

    $otogiri->bulk_insert(
        'book', 
        [qw| title author |],
        [
            {title => 'Acmencyclopedia 2009', author => 'Makamaka Hannyaharamitu'},
            {title => 'Acmencyclopedia Reverse', author => 'Makamaka Hannyaharamitu'},
            {title => 'Acmencyclopedia 2010', author => 'Makamaka Hannyaharamitu'},
            {title => 'Acmencyclopedia 2011', author => 'Makamaka Hannyaharamitu'},
            {title => 'Acmencyclopedia 2012', author => 'Makamaka Hannyaharamitu'},
            {title => 'Acmencyclopedia 2013', author => 'Makamaka Hannyaharamitu'},
            {title => 'Miyabi-na-Perl Nyuumon', author => 'Miyabi-na-Rakuda'},
            {title => 'Miyabi-na-Perl Nyuumon 2nd edition', author => 'Miyabi-na-Rakuda'},
        ],
    );

=head1 DESCRIPTION

Otogiri::Plugin::BulkInsert is A plugin for otogiri that provides 'bulk insert' method.

=head1 METHODS

=head2 $otogiri->bulk_insert($tablename, [ @colnames ], [ @rowdatas ]);

Insert multiple rowdata into specified table.

=head1 LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=cut

