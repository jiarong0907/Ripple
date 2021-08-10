mitigation = panorama (100)
.filter(victimLks.size > 1)
.when([sip IN pulsewaves], fwd=f_drop)