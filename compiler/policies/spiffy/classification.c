ingress = panorama (100)
.filter(link IN victimLks)
.when([reroute == 0])
.reduce([sip], [flowsz1], [pktlen])
.when([reroute == 1])
.reduce([sip], [flowsz2], [pktlen])

rerouteip = panorama (100)
.filter(link IN victimLks)
.when([victimLks.size > 1], fwd=f_reroute)
// set reroute to 1
.reduce([*], [reroute], [1])


suspicious = panorama (100)
.filter(victimLks.size > 1)
.filter(reroute == 1)
.zip([sip], [flowsz1], [flowsz2])
.filter(flowsz2 - flowsz1 < 3000)
