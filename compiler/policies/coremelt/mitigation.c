mitigation = panorama (100)
.filter(victimLks.size > 1)
.when([sip,dip,sport,dport IN suspicious], fwd=f_drop)