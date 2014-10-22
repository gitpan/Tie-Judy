# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Tie-Judy.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 108;
use Tie::Hash;
use Devel::Peek;
use Time::HiRes;

BEGIN { use_ok('Tie::Judy') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# do everything with both tied and object interface

my %judy;
my $tied = tie(%judy, 'Tie::Judy');
my $obj  = Tie::Judy->new();
isa_ok($tied, 'Tie::Judy');
isa_ok $obj, 'Tie::Judy';

isa_ok($$tied, 'judySLPtr');
isa_ok $$obj, 'judySLPtr';

# can store 1 key
is($judy{foo} = 2, 2);
is($judy{foo}, 2);

$obj->insert('foo', 2);
is $obj->retrieve('foo')->[0], 2;

is(%judy, 1);
is $obj->count, 1;

# can change value
my $one = 1;
is($judy{foo} = 1, 1);
is($judy{foo}, 1);

$obj->insert('foo', 1);
is $obj->retrieve('foo')->[0], 1;

is(%judy, 1);
is $obj->count, 1;

# can store a different key
is($judy{bar} = 3, 3);
is($judy{bar}, 3);

$obj->insert('bar', 3);
is $obj->retrieve('bar')->[0], 3;

is(%judy, 2);
is $obj->count, 2;

# defined
ok(defined $judy{foo});
ok defined $obj->retrieve('foo')->[0];

# not defined
ok(! defined $judy{baz});
ok ! defined $obj->retrieve('baz')->[0];

# value not def
is($judy{baz}, undef);
is $obj->retrieve('baz')->[0], undef;


my $bigkey = "0123456789" x 100000;
is($judy{$bigkey} = 4, 4);
is($judy{$bigkey}, 4);

$obj->insert($bigkey, 4);
is $obj->retrieve($bigkey)->[0], 4;


is(%judy, 3);
is $obj->count, 3;

# check that keys works (and they're in order!)
is_deeply([keys %judy], [ $bigkey, 'bar', 'foo' ]);
is_deeply [$obj->keys], [ $bigkey, 'bar', 'foo' ];

# check that it works twice
is_deeply([keys %judy], [ $bigkey, 'bar', 'foo' ]);
is_deeply [$obj->keys], [ $bigkey, 'bar', 'foo' ];

# check values
is_deeply([values %judy], [ 4, 3, 1 ]);
is_deeply [$obj->values], [ 4, 3, 1 ];

# add another key, then try again
$judy{'fop'} = 5;
$obj->insert('fop', 5);

is(%judy, 4);
is $obj->count, 4;

is_deeply([keys %judy], [ $bigkey, 'bar', 'foo', 'fop' ]);
is_deeply([$obj->keys], [ $bigkey, 'bar', 'foo', 'fop' ]);

# check that each works
my $j = 0;
while (my($k, $v) = each %judy) {
  is($k, $j == 0 ? $bigkey : $j == 1 ? 'bar' : $j == 2 ? 'foo' : 'fop');
  is($v, $j == 0 ? 4       : $j == 1 ? 3     : $j == 2 ? 1     : 5    );
  $j++;
}

# check object version in scalar context
for ($bigkey, qw(bar foo)) {
  is $obj->keys, $_;
}

# check out delete
is(delete $judy{'fop'}, 5);
is $obj->remove('fop')->[0], 5;

is_deeply([keys %judy], [ $bigkey, 'bar', 'foo' ]);
is_deeply [$obj->keys], [ $bigkey, 'bar', 'foo' ];

is_deeply([values %judy], [ 4, 3, 1 ]);
is_deeply [$obj->values], [ 4, 3, 1 ];

is(%judy, 3);
is $obj->count, 3;

# check bogus delete
is(delete $judy{'nope'}, undef);
is $obj->remove('nope')->[0], undef;

is_deeply([keys %judy], [ $bigkey, 'bar', 'foo' ]);
is_deeply [$obj->keys], [ $bigkey, 'bar', 'foo' ];

is_deeply([values %judy], [ 4, 3, 1 ]);
is_deeply [$obj->values], [ 4, 3, 1 ];

is(%judy, 3);
is $obj->count, 3;

is(delete $judy{$bigkey}, 4);
is $obj->remove($bigkey)->[0], 4;

is_deeply([keys %judy], [ 'bar', 'foo' ]);
is_deeply [$obj->keys], [ 'bar', 'foo' ];

is_deeply([values %judy], [ 3, 1 ]);
is_deeply [$obj->values], [ 3, 1 ];

is(%judy, 2);
is $obj->count, 2;

# check that value can go out of scope

{
  my $val = 1;
  $judy{'foo'} = $val;
  $obj->insert('foo', $val);
}

is($judy{'foo'}, 1);
is $obj->retrieve('foo')->[0], 1;

# check hash clearing
%judy = ();
$obj->CLEAR();

is_deeply([keys   %judy], []);
is_deeply [$obj->keys  ], [];

is_deeply([values %judy], []);
is_deeply [$obj->values], [];

is(%judy, 0);
is $obj->count, 0;

# check that insert() and retrieve() methods work
$tied->insert( { a => 1, b => 2, c => 3 } );
$obj->insert ( { a => 1, b => 2, c => 3 } );

is_deeply([keys   %judy], [qw(a b c)]);
is_deeply [$obj->keys  ], [qw(a b c)];

is_deeply([values %judy], [qw(1 2 3)]);
is_deeply [$obj->values], [qw(1 2 3)];

is(%judy, 3);
is $obj->count, 3;

is_deeply([$tied->retrieve(qw(a b c))], [qw(1 2 3)]);
is_deeply [$obj->retrieve( qw(a b c))], [qw(1 2 3)];

# check non-hashref insert
$tied->insert( a => 4, b => 5, c => 6 );
$obj->insert ( a => 4, b => 5, c => 6 );

is_deeply([$tied->retrieve(qw(a b c))], [qw(4 5 6)]);
is_deeply [$obj->retrieve(qw(a b c))], [qw(4 5 6)];

# check multiple remove
$tied->remove(qw(a b c));
$obj->remove(qw(a b c));

is(%judy, 0);
is $obj->count, 0;

# check multiple arg insert; hashref and array ref
$tied->insert( a => 1, { b => 2 }, [ c => 3 ] );
$obj->insert ( a => 1, { b => 2 }, [ c => 3 ] );

is_deeply([keys   %judy], [qw(a b c)]);
is_deeply [$obj->keys  ], [qw(a b c)];

is_deeply([values %judy], [qw(1 2 3)]);
is_deeply [$obj->values], [qw(1 2 3)];

is(%judy, 3);
is $obj->count, 3;

is_deeply([$tied->retrieve(qw(a b c))], [qw(1 2 3)]);
is_deeply [$obj->retrieve( qw(a b c))], [qw(1 2 3)];

# test retrieve with array ref

is_deeply([$tied->retrieve([qw(a b c)])], [qw(1 2 3)]);
is_deeply([$obj->retrieve([qw(a b c)])], [qw(1 2 3)]);

# remove with array ref
$tied->remove([qw(a b c)]);
$obj->remove([qw(a b c)]);

is(%judy, 0);
is $obj->count, 0;
