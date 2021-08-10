ingress = panorama (100)
.filter(link == 0)
.reduce ([sip], [inflowsz], [pktlen])

egress = panorama (100)
.filter(link == 2)
.reduce ([sip], [egflowsz], [pktlen])


keyflows = panorama (100)
.filter(link == 2)
.zip([sip], [inflowsz], [egflowsz])
.filter(inflowsz - egflowsz > 500)
.filter(sip IN IPSET[1.2.0.0/16])
