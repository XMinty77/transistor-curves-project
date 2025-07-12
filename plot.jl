using DataStructures
using GLMakie
using Dates

plot_time = now()

# Initializes plotting objects
function plot_init()
    # Observable data point that can live update the plot once mutated
    # Indexed and sorted by corresponding base current
    curves = SortedDict{Float64, Observable}()

    # Figure and axes
    fig = Figure()
    ax = Axis(fig[1, 1])

    # TODO: Unit conversion and accounting for resistors
    limits!(ax, 0, 1024, 0, 1024)

    # Display in a window
    display(fig)

    # Saving data on exitting
    atexit() do
        plot_save("backup", curves, now())
    end

    return curves
end

function plot_save(folder, curves, name = plot_time)
    println("Saving $folder...")
    open("$folder/$name.csv", "w") do io
        for (ib, curve) in curves
            println(io, ib);
            println(io, join([p[1] for p in curve[]], ","))
            println(io, join([p[2] for p in curve[]], ","))
            println(io)
        end
    end
end