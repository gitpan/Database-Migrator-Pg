
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}

use strict;
use warnings;

use Test::Database::Migrator;
use Test::More 0.88;

use Database::Migrator::Pg;

{
    package Test::Database::Migrator::Pg;

    use Moose;
    extends 'Test::Database::Migrator';

    around _write_ddl_file => sub {
        my $orig = shift;
        my $self = shift;
        my $file = shift;
        my $ddl  = shift;

        $ddl = <<"EOF";
SET CLIENT_MIN_MESSAGES = ERROR;

$ddl
EOF

        $self->$orig( $file, $ddl );
    };

    sub _tables {
        my $self = shift;

        my @tables;

        my $sth = $self->_dbh()->table_info( undef, 'public', undef, undef );
        while ( my $table = $sth->fetchrow_hashref() ) {
            push @tables, $table->{pg_table};
        }

        return sort @tables;
    }

    sub _indexes_on {
        my $self = shift;
        my $table = shift;

        my @indexes;

        my $sth = $self->_dbh()
            ->statistics_info( undef, 'public', $table, undef, undef );
        while ( my $index = $sth->fetchrow_hashref() ) {

            # With Pg we get some weird results back, including an index with
            # undef as the name.
            next
                unless $index->{INDEX_NAME}
                && $index->{COLUMN_NAME} !~ /_id$/;

            push @indexes, $index->{INDEX_NAME};
        }

        return sort @indexes;
    }
}

Test::Database::Migrator::Pg->new(
    class => 'Database::Migrator::Pg',
)->run_tests();

done_testing();
