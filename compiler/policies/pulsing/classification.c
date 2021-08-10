pulsewaves = panorama (100)
.reduce ([sip], [flowsz], [pktlen])
.zip([sip], [flowsz], [flowsz])
// use flowsz1 and flowsz2 to differentiate flowsz
.filter(flowsz1 - flowsz2 > 500)

