println("Loading packages...")

using GLMakie

println("Loading components...")

include("./plot.jl");
include("./serial.jl");

# Initialization
curves = plot_init()

# REPL hack as to close leaked serial streams
try
    close(sp)
catch (ex) end

println("Connecting to Arduino...")
sp = serial_init()

println("Starting update loop...")

# Update loop
# include("./update_pot.jl")
include("./update_cap.jl")
while true
    update_loop()
end