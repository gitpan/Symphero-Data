# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
###########################################################################
use strict;

sub tprint ($$)
{ my ($name,$rc)=@_;
  print $name,'.' x (50-length($name)),".",$rc ? "ok" : "NOT OK","\n";
}

sub load_module ($)
{ my $module=shift;
  eval "use $module";
  my $err=$@;
  my $ver=$err ? 'BAD' : (eval ('$' . $module . '::VERSION') || 'BAD');
  tprint "$module<$ver>", ! $err;
  die $err if $err;
}

##########################################################################
load_module "Symphero::Utils";

##
# HTML stuff
#
my $str='\'"!@#$%^&*()_-=[]\<>?';
my $str1=t2ht($str);
tprint "t2ht()", $str1 eq '\'"!@#$%^&amp;*()_-=[]\&lt;&gt;?';
$str1=t2hq($str);
tprint "t2hq()", $str1 eq '\'%22!@%23$%25^%26*()_-%3d[]\<>%3f';
$str1=t2hf($str);
tprint "t2hf()", $str1 eq '\'&quot;!@#$%^&amp;*()_-=[]\&lt;&gt;?';

##
# Arguments
#
my $args=get_args(a => 1, b => 2);
tprint "get_args(%a)", $args->{a} == 1 && $args->{b} == 2;
$args=get_args([a => 2, b => 3]);
tprint "get_args(\@_)", $args->{a} == 2 && $args->{b} == 3;
$args=get_args({a => 3, b => 4});
tprint "get_args(\%a)", $args->{a} == 3 && $args->{b} == 4;

##
# ID
#
my $key=generate_key();
tprint 'generate_key()', $key =~ /^[0-9A-Z]{8}/;
$key=repair_key('01V34567');
tprint 'repair_key()', $key eq 'OIU3456I';

##########################################################################
load_module "Symphero::SimpleHash";
tprint "UNIMPLEMENTED TESTS", 1;

##########################################################################
load_module "Symphero::MultiValueHash";
tprint "UNIMPLEMENTED TESTS", 1;

##########################################################################
load_module "Symphero::MultiValueDB";
tprint "UNIMPLEMENTED TESTS", 1;

1;
