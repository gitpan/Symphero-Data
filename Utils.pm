##
# Various supporting functions
#
package Symphero::Utils;
use strict;
use Carp;

##
# Prototypes
#
sub generate_key (;$);
sub repair_key ($);
sub set_debug ($);
sub dprint (@);
sub eprint (@);
sub t2ht ($);
sub t2hf ($);
sub t2hq ($);
sub get_args (@);

##
# Package version
use vars qw($VERSION);
($VERSION)=(q$Id: Utils.pm,v 1.3 2001/03/02 00:32:55 amaltsev Exp $ =~ /(\d+\.\d+)/);

##
# Exporting subroutines outside
#
use vars qw(@ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( dprint
              eprint
              generate_key
              repair_key
              t2ht t2hq t2hf
              get_args
            );

##
# Generating new 8-characters random ID. Not guaranteed to be unique,
# must be checked against existing database.
#
# You can pass additional argument to add some more randomness.
#
# Generated ID is relativelly suitable for humans - it does not contain
# letters that looks similar to digits.
#
# Letters I and V and digits 0 and 7 are dropped from the list.
#
sub generate_key (;$)
{ #                        1    1    2    2    3
  #              0----5----0----5----0----5----0-
  my $symbols = "2345689ABCDEFGHIJKLMNOPQRSTUWXYZ";
  my $rval=pack("SSC",rand(0x10000),rand(0x10000),unpack("%8C*",$_[0] || "foo"));
  my $key='';
  while(!$key || $key=~/^[0-9W]+$/)
   { for(my $i=0; $i!=8; $i++)
      { my $v=vec($rval,$i+2,4) + vec($rval,$i,1)*16;
        $key.=substr($symbols,$v,1);
      }
   }
  $key;
}

##
# Repairing human-entered ID. Similar letters substituted to allowed
# ones.
#
sub repair_key ($)
{ my $key=uc($_[0]);
  $key=~s/[\r\n\s]//sg;
  return undef unless length($key) == 8;
  $key=~s/0/O/g;
  $key=~s/1/I/g;
  $key=~s/7/I/g;
  $key=~s/V/U/g;
  $key;
}

##
# Turning debug flag on or off. The flag is global for all packages that
# use Symphero::Utils!
#
my $debug_flag=0;
sub set_debug ($)
{ $debug_flag=$_[0];
}

##
# Debug output
#
sub dprint (@)
{ return unless $debug_flag;
  my $str=join("",map { defined($_) ? $_ : "<UNDEF>" } @_);
  chomp $str;
  print STDERR $str,"\n";
}

##
# Error output
#
sub eprint (@)
{ my $str=join("",map { defined($_) ? $_ : "<UNDEF>" } @_);
  chomp $str;
  print STDERR "*ERROR: ",$str,"\n";
}

##
# Escapes text to be good in HTML.
#
sub t2ht ($)
{ my $text=shift;
  $text=~s/&/&amp;/sg;
  $text=~s/</&lt;/sg;
  $text=~s/>/&gt;/sg;
  $text;
}

##
# Escapes text for HTML tags arguments.
#
sub t2hf ($)
{ my $text=t2ht($_[0]);
  $text=~s/"/&quot;/sg;
  $text=~s/([\x00-\x1f\x80-\x9f])/"&#".ord($1).";"/sge;
  $text;
}

##
# Escapes text for HTML query values.
#
sub t2hq ($)
{ my $text=shift;
  $text=~s/([\x00-\x20\x80-\xff\&\?"=%#+])/"%".unpack("H2",$1)/sge;
  $text;
}

##
# Gets arguments hash reference from parameters array. Called as:
# sub xxx ($%)
# { my $self=shift;
#   my $args=get_args(\@_);
#
# Allows to call xxx as:
# $self->xxx({a => 1, b => 2});
# and as:
# $self->xxx(a => 1, b => b);
#
sub get_args (@)
{ my $arr=ref($_[0]) eq "ARRAY" ? $_[0] : \@_;
  my $args;
  if(@{$arr} == 1)
   { $args=$arr->[0];
     carp "Symphero::Utils::get_args - Not a HASH in arguments" unless ref($args) eq "HASH";
   }
  elsif(! (scalar(@{$arr}) % 2))
   { my %a=@{$arr};
     $args=\%a;
   }
  else
   { carp "Symphero::Utils::get_args - unparsable arguments";
   }
  $args={} unless $args;
#  carp "--- get_args";
#  foreach my $n (keys %{$args})
#   { dprint "get_args $n => $args->{$n}";
#   }
  $args;
}

##
# Defining class for symphero handler errors.
#
package Symphero::Errors::Handler;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
1;
__END__

=head1 NAME

Symphero::Utils - Utility functions widely used by Symphero modules

=head1 SYNOPSIS

  use Symphero::Utils;

  or

  use Symphero::Utils (); # do not export any functions

=head1 DESCRIPTION

To be extended..

=head1 EXPORTS

eprint(), dprint(), t2ht(), t2hf(), t2hq(), generate_key(),
repair_key(), get_args().

=head1 AUTHOR

Andrew Maltsev, <amaltsev@valinux.com>

=head1 SEE ALSO

=cut
