using GLMakie
using CSV
using DelimitedFiles

# Read and parse the data.csv
function read_custom_csv(filepath)
    lines = readlines(filepath)
    datasets = []

    i = 1
    while i <= length(lines)
        if isempty(strip(lines[i]))
            i += 1
            continue
        end
        label = strip(lines[i])
        x = parse.(Float64, split(lines[i + 1], ','))
        y = parse.(Float64, split(lines[i + 2], ','))
        push!(datasets, (label="Ib = $label µA", x=x, y=y))
        i += 4
    end

    return datasets
end

# Main plotting function
function main()
    datasets = read_custom_csv("data_cleaned.csv")

    # Scatter plot
    fig1 = Figure(resolution = (800, 600))
    ax1 = Axis(fig1[1, 1], title = "Ic-Vce characteristics", xlabel="Vce (V)", ylabel="Ic (mA)")
    for data in datasets
        scatter!(ax1, data.x, data.y, label = data.label)
    end
    axislegend(ax1)
    save("scatter_plot.png", fig1)

    # Sorted line plot
    fig2 = Figure(resolution = (800, 600))
    ax2 = Axis(fig2[1, 1], title = "Ic-Vce characteristics", xlabel="Vce (V)", ylabel="Ic (mA)")
    for data in datasets
        x, y = sortperm(data.x), data.y
        sorted_x = data.x[x]
        sorted_y = data.y[x]
        lines!(ax2, sorted_x, sorted_y, label = data.label)
    end
    axislegend(ax2)
    save("sorted_line_plot.png", fig2)
end

main()
