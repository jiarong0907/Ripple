mitigation = panorama (100)
.filter(victimLks.size > 1)
.when([sip, dip, sport, dport IN mal_coremelt], fwd=f_drop)
.when([sip, dip IN mal_crossfire], fwd=f_reroute)