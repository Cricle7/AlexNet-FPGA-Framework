

vlib work

#Load the design.
vlog -f flist
vsim -t ps +notimingchecks -gui -voptargs="+acc" work.tb_QuantizedConvReLU2d
#do wave.do
#Run simulation
#run 150ms
#run 150ms
