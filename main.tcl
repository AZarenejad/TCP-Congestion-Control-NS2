#Make a NS simulator 
set ns [new Simulator]  

#set TCP variant from commandline
set variant [lindex $argv 0]
set num_run [lindex $argv 1]


#Open the nam file basic.nam and the variable-trace file basic.tr
set namfile [open main.nam w]
$ns namtrace-all $namfile
set filetrace "$variant/droprate/tracefiles/$num_run.tr"
puts $filetrace
set tracefile [open $filetrace w]
$ns trace-all $tracefile



# Define a 'finish' procedure
proc finish {} {

        exit 0
}

# Create the nodes:
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]
set n4 [$ns node]
set n5 [$ns node]


proc randomGenreator {min max} {
        return [expr $min + round(rand() * ($max - $min))]
}


# Create the links:
$ns duplex-link $n0 $n2 100Mb 5ms DropTail
$ns duplex-link $n1 $n2 100Mb [randomGenreator 5 25]ms DropTail
$ns duplex-link $n2 $n3 100Kb 1ms DropTail
$ns duplex-link $n3 $n4 100Mb 5ms DropTail
$ns duplex-link $n3 $n5 100Mb [randomGenreator 5 25]ms DropTail

#define position 
$ns duplex-link-op $n0 $n2 orient right-down
$ns duplex-link-op $n1 $n2 orient right-up
$ns duplex-link-op $n2 $n3 orient right
$ns duplex-link-op $n3 $n4 orient right-up
$ns duplex-link-op $n3 $n5 orient right-down



# ########################################################
# Set Queue Size of link  to 10 (default is 50 ?)
$ns queue-limit $n2 $n3 10
$ns queue-limit $n3 $n4 10
$ns queue-limit $n3 $n5 10


set tcp0 [new Agent/TCP]
set tcp1 [new Agent/TCP]

#set a TCP
if {$variant == "Tahoe"} {
	set tcp0 [new Agent/TCP]
    set tcp1 [new Agent/TCP]
} elseif {$variant == "Newreno"} {
	set tcp0 [new Agent/TCP/Newreno]
    set tcp1 [new Agent/TCP/Newreno]
} elseif {$variant == "Vegas"} {
	set tcp0 [new Agent/TCP/Vegas]
    set tcp1 [new Agent/TCP/Vegas]
}


# Add a TCP sending module to node n0
$ns attach-agent $n0 $tcp0

# Add a TCP sending module to node n1
$ns attach-agent $n1 $tcp1

$tcp0 set class_ 0
$tcp1 set class_ 1
$ns color 0 Red
$ns color 1 Blue
$tcp0 set ttl_ 64
$tcp1 set ttl_ 64


# Add a TCP receiving module to node n4
set sink0 [new Agent/TCPSink]
$ns attach-agent $n4 $sink0

# Add a TCP receiving module to node n5
set sink1 [new Agent/TCPSink]
$ns attach-agent $n5 $sink1

# Direct traffic from "tcp0" to "sink0"
$ns connect $tcp0 $sink0

# Direct traffic from "tcp1" to "sink1"
$ns connect $tcp1 $sink1

# Setup a FTP traffic generator on "tcp0"
set ftp0 [new Application/FTP]
$ftp0 attach-agent $tcp0
$ftp0 set type_ FTP          

# Setup a FTP traffic generator on "tcp1"
set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1
$ftp1 set type_ FTP  

# Schedule start/stop times
$ns at 0.0   "$ftp0 start"
$ns at 1000.0 "$ftp0 stop"
$ns at 0.0  "$ftp1 start"
$ns at 1000.0 "$ftp1 stop"


# Set simulation end time
$ns at 1000.0 "finish" 



##################################################
## Obtain Trace date at destination (n4) (n5)
##################################################

proc plotWindow {tcpSource outfile} {
   global ns
   set now [$ns now]
   set cwnd [$tcpSource set cwnd_]

###Print TIME CWND   for  gnuplot to plot progressing on CWND   
   puts  $outfile  "$now $cwnd"

   $ns at [expr $now+1] "plotWindow $tcpSource  $outfile"
}




set file_cwnd0 "$variant/cwnd/flow0/$num_run.txt"
set file_goodput0 "$variant/goodput/flow0/$num_run.txt"
set file_rtt0 "$variant/rtt/flow0/$num_run.txt"
set file_cwnd1 "$variant/cwnd/flow1/$num_run.txt"
set file_goodput1 "$variant/goodput/flow1/$num_run.txt"
set file_rtt1 "$variant/rtt/flow1/$num_run.txt"

set outfile0 [open  $file_cwnd0  w]
set outfile1 [open  $file_cwnd1  w]
set trace_file0 [open  $file_goodput0  w]
set trace_file1 [open  $file_goodput1  w]
set out0 [open  $file_rtt0  w]
set out1 [open  $file_rtt1  w]



$ns  at  0.0  "plotWindow $tcp0  $outfile0"
$ns  at  0.0  "plotWindow $tcp1  $outfile1"



##################################################
## Obtain Trace date at destination (n4) (n5)
##################################################

source TraceApp.ns

proc plotThroughput {tcpSink outfile} {
   global ns
   set now [$ns now]
   set nbytes [$tcpSink set bytes_]
   $tcpSink set bytes_ 0
   set time_incr 1.0
   set throughput [expr ($nbytes * 8.0 / 1000000) / $time_incr]
###Print TIME throughput for  gnuplot to plot progressing on throughput
   puts  $outfile  "$now $throughput"
   $ns at [expr $now+$time_incr] "plotThroughput $tcpSink  $outfile"
}


set traceapp0 [new TraceApp]	  ;# Create a TraceApp object
set traceapp1 [new TraceApp]	  ;# Create a TraceApp object

$traceapp0 attach-agent $sink0     ;# Attach traceapp to 
$traceapp1 attach-agent $sink1     ;# Attach traceapp to TCPSink

$ns  at  0.0  "$traceapp0  start"  ;# Start the traceapp object
$ns  at  0.0  "$traceapp1  start"  ;# Start the traceapp object

$ns  at  0.0  "plotThroughput $traceapp0  $trace_file0"
$ns  at  0.0  "plotThroughput $traceapp1  $trace_file1"




################## CAlC RTT #########################

for {set  i 0} { $i < 1000} {set i [expr {$i + 1}]} {
        $ns at $i "calcRtt $tcp0  $out0 $i"
        $ns at $i "calcRtt $tcp1  $out1  $i"
}

proc calcRtt {tcpSource outfile time} {
        set rtt [$tcpSource set rtt_]
        puts  $outfile  "$time $rtt"
}


# Run simulation !!!!
$ns run














