package Tie::Judy;

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.02';

require XSLoader;
XSLoader::load('Tie::Judy', $VERSION);

sub new {
  my $pkg = shift;
  return $pkg->TIEHASH(@_);
}

sub TIEHASH {
  my ($pkg) = @_;

  my $judy = judy_new_judySL();

  return bless \$judy, $pkg;
}

sub EXISTS {
  my $this = shift;

  return defined judy_JSLG($$this, @_);
}

sub DELETE {
  my $this = shift;

  return judy_JSLD($$this, @_);
}

sub remove {
  my $this = shift;

  my $judy = $$this;
  my @values = map judy_JSLD($judy, $_), @_;

  return wantarray ? @values : \@values;
}

sub STORE {
  my $this = shift;

  return judy_JSLI($$this, @_);
}

sub insert {
  my $this = shift;

  my $judy = $$this;
  if (@_ == 1) {
    unless (UNIVERSAL::isa($_[0], 'HASH')) {
      Carp::croak "Usage: \$tied->insert(HASHREF) or \$tied->insert(KEY, VALUE, ...)\n";
    }
    while (my($k, $v) = each %{ $_[0] }) {
      judy_JSLI($judy, $k, $v);
    }
  } else {
    for (my $i = 0; $i < $#_; $i+=2) {
      judy_JSLI($judy, $_[$i], $_[$i + 1]);
    }
  }

  return;
}

sub FETCH {
  my $this = shift;

  return judy_JSLG($$this, @_);
}

sub retrieve {
  my $this = shift;

  my $judy = $$this;
  my @values = map judy_JSLG($judy, $_), @_;
  return wantarray ? @values : \@values;
}

sub FIRSTKEY {
  my $this = shift;

  return judy_JSLF($$this);
}

sub NEXTKEY {
  my $this = shift;

  return judy_JSLN($$this);
}

my %last_key;
sub keys {
  my $this = shift;

  if (wantarray) {
    my $key = $this->FIRSTKEY;
    my @keys;
    while (defined $key) {
      push @keys, $key;
      $key = $this->NEXTKEY;
    }

    delete $last_key{$this};
    return @keys;
  } elsif (defined $last_key{$this}) {
    return $last_key{$this} = $this->NEXTKEY;
  } else {
    return $last_key{$this} = $this->FIRSTKEY;
  }

  return;
}

sub values {
  my $this = shift;

  if (wantarray) {
    return map judy_JSLG($$this, $_), $this->keys;
  } elsif (defined $last_key{$this}) {
    return judy_JSLG($$this, $last_key{$this} = $this->NEXTKEY);
  } else {
    return judy_JSLG($$this, $last_key{$this} = $this->FIRSTKEY);
  }
}

sub CLEAR {
  my $this = shift;

  judy_JSLFA($$this);

  return;
}

sub SCALAR {
  my $this = shift;

  return judy_count($$this);
}

*count = *SCALAR;

sub DESTROY { }

package judySLPtr;

sub DESTROY {
  my $this = shift;

  Tie::Judy::judy_JSLFA($this);
  Tie::Judy::judy_free_judySL($this);

  return;
}

1;
__END__

=head1 NAME

Tie::Judy - Perl extension for using a Judy array instead of a hash.

=head1 SYNOPSIS

  use Tie::Judy;

  tie %judy, 'Tie::Judy'; # %judy now reads and writes to a Judy array.

  keys   %judy; # the keys here are in bit-wise SORTED order.
  values %judy; # the values here are in the same order as the keys

  0 + %judy; # returns the number of keys

  # method to add lots of entries at once
  (tied %judy)->insert( { key => 'value', ... } );
  (tied %judy)->insert(   key => 'value', ...   );

  # method to retrieve lots of values at once
  (tied %judy)->retrieve( 'key1', 'key2', ... );

  # method to remove lots of entries at once
  (tied %judy)->remove( 'key1', 'key2', ... );

  # OBJECT-ORIENTED INTERFACE
  my $judy = Tie::Judy->new();

  @keys   = $judy->keys;
  @values = $judy->values;

  $count  = $judy->count;

  $judy->insert(   key => 'value', ...   );
  $judy->insert( { key => 'value', ... } );

  # retrieve and remove return arrays in list context, array refs in scalar context

  $judy->retrieve( 'key1', 'key2', ... );

  $judy->remove( 'key1', 'key2', ... );

=head1 DESCRIPTION

=head2 EXPORT

No exports.

=head1 SEE ALSO

The Judy Array project page: http://judy.sourceforge.net/

=head1 AUTHOR

Benjamin Holzman, E<lt>bholzman@earthlink.net<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Benjamin Holzman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
