mitigation = panorama (100)
.filter(victimLks.size > 1)
.when([sip, dip IN suspicious], fwd=f_reroute)