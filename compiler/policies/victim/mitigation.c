mitigation = panorama (100)
.filter(victimLks.size > 1)
.filter(link != 2)
.when([dip IN victim], fwd=f_reroute)
