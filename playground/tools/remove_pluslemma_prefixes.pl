#!/usr/bin/perl


my %prefix = map { ($_, 1) } qw(
F0+ F1+ F4+ F5+ F6+ F7+ F8+ F9+ F:+ FB+ FD+ FE+ FH+ FJ+ FK+ FL+ FN+ FP+ FQ+ FS+
FW+ FY+ FZ+ Fc+ Ff+ Fi+ Fp+ Fq+ Ft+ L*---+ L,---+ L,P--+ L,S--+ L2-A-+ L=---+
L?---+ L@---+ LADA1+ LADA2+ LADA3+ LADN1+ LAPA1+ LAPA2+ LAPA3+ LAPN1+ LAPN2+
LAPN3+ LASA1+ LASA2+ LASA3+ LASN1+ LASN2+ LASN3+ LAXA1+ LBPA-+ LBPN-+ LBSA-+
LBSN-+ LBXA-+ LCPA-+ LCPN-+ LCSA-+ LCSN-+ LCWA-+ LCWN-+ LGDA-+ LGPA-+ LGPN-+
LGSA-+ LGSN-+ LI---+ LMPA-+ LMPN-+ LMSA-+ LMSN-+ LNDA-+ LNPA-+ LNPN-+ LNSA-+
LNSN-+ LNXA-+ LNXN-+ LOP--+ LOS--+ LR-+ LR1+ LR2+ LR3+ LR4+ LR6+ LR7+ LRX+
LT---+ LUD--+ LUP--+ LUS--+ LUX--+ LX---+ L^---+ La---+ Lb---+ Lb-A-+ Lb-N-+
LdD--+ LdP--+ LdS--+ LePA-+ LePN-+ LeSA-+ LeSN-+ Lf-A-+ Lf-N-+ Lg-A1+ Lg-A2+
Lg-A3+ Lg-N1+ Lg-N2+ Lg-N3+ LhD--+ LhP--+ LiPA-+ LiPN-+ LiSA-+ LiSN-+ LjS--+
LkP--+ LlD--+ LlP--+ LlS--+ LlX--+ LmPA-+ LmPN-+ LmSA-+ LmSN-+ LnP--+ LnS--+
LnX--+ Lo---+ LpPA-+ LpPN-+ LpSA-+ LpSN-+ LpWA-+ LpWN-+ LqPA-+ LqPN-+ LqSA-+
LqSN-+ LqWA-+ LqWN-+ LrD--+ LrP--+ LrS--+ LsPA-+ LsPN-+ LsSA-+ LsSN-+ LsWA-+
LsWN-+ LtPA-+ LtPN-+ LtSA-+ LtSN-+ Lu---+ Lv---+ LwP--+ LwS--+ Lx---+ LyP--+
LyS--+ LzP--+ LzS--+ L}---+);

sub remove {
  my $s = shift;
  my $mayprefix = shift;
  return $mayprefix.$s if !defined $prefix{$s};
  return $mayprefix;
}

while (<>) {
  s/^([^\s]+\+)/remove $1, ""/ge;
  s/ ([^\s]+\+)/remove $1, " "/ge;
  print $_;
}
