using Statistics
using GLMakie

include("./utils.jl")

# TODO: Consider more efficient binary protocol and increasing polling rate

# Arduino's pushing rate, we wait half of that
const UPDATE_ARDUINO_RATE = 0.1;
const UPDATE_POLLING_RATE = UPDATE_ARDUINO_RATE / 2;
const UPDATE_BADWAIT_TIME = ceil(0.5 / UPDATE_ARDUINO_RATE)

# Inbound data indices
const UPDATE_INDEX_VCE = 1
const UPDATE_INDEX_ICC = 2
const UPDATE_INDEX_IBB = 3
const UPDATE_INDEX_VBB = 4
const UPDATE_INDEX_VCC = 5
const UPDATE_INDEX_MAX = 5

const UPDATE_IBB_COUNT      = 10        # Number of most recent Ibb points to consider when checking variance for stability
const UPDATE_IBB_COUNT_MEAN = 5         # Number of most recent Ibb points to consider when calculating the mean

# update_wait constants
const UPDATE_WAIT_IBB_TOL_SDEV   = 1    # Maximum standard deviation allowed in order to consider a set of Ibb values stable
const UPDATE_WAIT_IBB_TOL_GOBACK = 4    # Maximum difference from old equilibrium allowed in order to go back to it

# update_add constants
const UPDATE_ADD_VCC_DELTA_NOISE = 3    # Tolerated noise level for VCC
const UPDATE_ADD_VBB_DELTA_NOISE = 3    # Tolerated noise level for VBB
const UPDATE_ADD_IBB_DELTA_NOISE = 4    # Tolerated noise level for IBB

const UPDATE_ADD_VCE_DELTA_DUPE  = 1.5  # Maximum difference between two VCE values to consider them the same
const UPDATE_ADD_ICC_DELTA_DUPE  = 1.5  # Maximum difference between two ICC values to consider them the same

# update_drift constants
const UPDATE_DRIFT_IBB_DELTA_VALUE = 4  # Tolerated difference in single values
const UPDATE_DRIFT_IBB_DELTA_MEANS = 3  # Tolerated difference in means

# Initialization state, fills up VBB values before starting
function update_start()
    global update_ibb_mem = push!(update_ibb_mem, update_data[UPDATE_INDEX_IBB])
    global update_vbb_mem = push!(update_vbb_mem, update_data[UPDATE_INDEX_VBB])
    global update_vcc_mem = push!(update_vcc_mem, update_data[UPDATE_INDEX_VCC])

    if (length(update_ibb_mem) == UPDATE_IBB_COUNT)
        global update_ibb_equ = mean(update_ibb_mem)
        global update_vbb_equ = mean(update_vbb_mem)
        global update_vcc_equ = mean(update_vcc_mem)

        # Go to waiting state to initiate a curve
        println("Initializing...")
        global update_state = update_wait
    end
end

# Stores polled data
update_data = []

# A memory of the most recent values received
update_ibb_mem = []
update_vbb_mem = []
update_vcc_mem = []

# These negative values prevent update_wait running at the very start from thinking it's going back to an old value
update_ibb_equ = -200
update_ibb_equ_old = -100
update_vbb_equ = -200
update_vcc_equ = -200

# Current state
update_state = update_start

# Update loop
function update_loop()
    # Delay to receive next batch of update_data and unblock main thread for the plot to refresh
    sleep(UPDATE_POLLING_RATE)

    data = nothing
    # Read and parse the next batch of update_data
    try
        data = split(readline(sp), ",")
    catch (ex)
        # Gracefully exit if the stream fails
        try close(sp) catch (_) end
        exit(0)

        return
    end

    if (length(data) < UPDATE_INDEX_MAX) return end

    try
        global update_data = parse.(Float64, data)
    catch (e) return end

    # Update in acoordance with the current state
    update_state()
end

# Adding points state, adds point to the current curve
function update_add()
    # Get data and do conversions
    vce, icc, ibb, vbb, vcc = update_data[[UPDATE_INDEX_VCE, UPDATE_INDEX_ICC, UPDATE_INDEX_IBB, UPDATE_INDEX_VBB, UPDATE_INDEX_VCC]]
    vcer, iccr, ibbr = convert_voltage(vce), convert_ic(icc), convert_ib(ibb)

    # Update the memories and means that we need in this state
    global update_ibb_mem = roll!(update_ibb_mem, update_data[UPDATE_INDEX_IBB])
    global update_vcc_mem = push!(update_vcc_mem, update_data[UPDATE_INDEX_VCC])

    if (abs(update_ibb_equ - ibb) >= UPDATE_ADD_IBB_DELTA_NOISE && abs(ibb - update_ibb_mem[end - 1]) >= UPDATE_ADD_IBB_DELTA_NOISE * 2)
        # Base current changed singificantly, go to waiting state

        if (abs(update_vcc_mem[end - 1] - vcc) >= UPDATE_ADD_VCC_DELTA_NOISE * 2)
            # Doesn't seem intentional, the capacitor is changing VCC
            # TODO: Wait for VCC to stop changing, this will be give very bad points
        else
            # Seems like an intentional change
            println("Base current changed from $update_ibb_equ, waiting for stabilized value...")
            global update_state = update_wait
            global update_ibb_equ_old = update_ibb_equ
            return
        end
    end

    # Get the current curve
    curve = curves[update_ibb_equ]

    # Check if the current point is too close to an existing one
    for (vce_, icc_) in curve[]
        if (abs(vcer - vce_) <= UPDATE_ADD_VCE_DELTA_DUPE && abs(iccr - icc_) <= UPDATE_ADD_ICC_DELTA_DUPE)
            return
        end
    end

    # Add a new point to the current curve
    curve[] = push!(curve[], Point2f([vcer, iccr]))
    notify(curve);
end

# Waiting for user state, waits until Ib is stable
function update_wait()
    ibb, vbb = update_data[[UPDATE_INDEX_IBB, UPDATE_INDEX_VBB]]

    global update_vbb_mem = roll!(update_vbb_mem, vbb)
    global update_vbb_equ = mean(update_vbb_mem)

    global update_ibb_mem = roll!(update_ibb_mem, ibb)
    global update_ibb_equ = mean(update_ibb_mem)

    sdev = stdm(update_ibb_mem, update_ibb_equ)

    # Continuously display base current in the terminal
    print("\r                                                                                    ")
    print("\rBase current: $ibb \t Mean: $update_ibb_equ \t Sdev: $sdev")

    if (sdev <= UPDATE_WAIT_IBB_TOL_SDEV)
        update_ibb_equ = mean(update_ibb_mem[end + 1 - UPDATE_IBB_COUNT_MEAN:end])

        println("\n")
        plot_save("data", curves)

        # Some noise can throw us off, if we didn't change the base current all that much then let's just go back to the original
        if (abs(update_ibb_equ_old - update_ibb_equ) < UPDATE_WAIT_IBB_TOL_GOBACK)
            println("Base current stabilized @ previous value of $update_ibb_equ_old, resuming...")
            global update_ibb_equ = update_ibb_equ_old
            global update_state = update_add
            return
        end
        
        # Base current has stabilized, go to adding state
        println("Base current stabilized @ new value of $update_ibb_equ, drawing a new curve...")
        global update_state = update_add

        # Add the new curve
        curve = Observable(Point2f[])
        curves[update_ibb_equ] = curve
        scatter!(curve);
    end
end