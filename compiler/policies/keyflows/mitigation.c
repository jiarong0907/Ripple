mitigation = panorama (100)
.filter(victimLks.size > 1)
// rereoute is done for ingress and other links except egress link
.filter(link != 2)
.when([dip IN keyflows], fwd=f_reroute)
