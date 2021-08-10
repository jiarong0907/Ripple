suspicious = panorama (100)
.filter(victimLks.size > 1)
// If the packet is sent to the congested link
.filter(link IN victimLks)
.reduce ([sip,dip,sport,dport], [flowsz], [pktlen])
.filter(flowsz > 11000)
