mitigation = panorama (100)
.filter(victimLks.size > 1)
.when([sip IN suspicious], fwd=f_drop)
