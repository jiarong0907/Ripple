ingress = panorama (100)
.filter(victimLks.size > 1)
.filter(link == 0)
.reduce ([dip], [inflowsz], [pktlen])

egress = panorama (100)
.filter(victimLks.size > 1)
.filter(link == 2)
.reduce ([dip], [egflowsz], [pktlen])

victim = panorama (100)
.filter(victimLks.size > 1)
// zip is done on egress link
.filter(link == 2)
.zip([dip], [inflowsz], [egflowsz])
.filter(inflowsz - egflowsz > 500)
