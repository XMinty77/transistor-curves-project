function parse_csv(file)
    lines = readlines(file)
    groups = []
    i = 1

    while i <= length(lines)
        if isempty(strip(lines[i]))
            i += 1
            continue
        end

        if i + 2 > length(lines)
            error("Unexpected file format near line $i")
        end

        label = strip(lines[i])
        x_vals = parse.(Float64, split(strip(lines[i+1]), ","))
        y_vals = parse.(Float64, split(strip(lines[i+2]), ","))

        if length(x_vals) != length(y_vals)
            error("Mismatched x and y length at label $label")
        end

        push!(groups, (label, x_vals, y_vals))
        i += 4  # move to next group (label, x, y, blank)
    end

    return groups
end

function clean_data(groups)
    cleaned = []

    for (label, x, y) in groups
        new_x = Float64[]
        new_y = Float64[]

        for i in 2:length(x)
            dx = x[i] - x[i-1]
            dy = y[i] - y[i-1]

            if dx == 0
                continue  # avoid division by zero
            end

            slope = dy / dx

            if slope >= -0.2 # TODO: Adjust this threshold
                push!(new_x, x[i])
                push!(new_y, y[i])
            end
        end

        push!(cleaned, (label, new_x, new_y))
    end

    return cleaned
end

function write_cleaned_csv(file, cleaned_data)
    open(file, "w") do io
        for (label, x, y) in cleaned_data
            println(io, label)
            println(io, join(x, ","))
            println(io, join(y, ","))
            println(io)
        end
    end
end

input_file = "data_uncleaned.csv"
output_file = "data_cleaned.csv"

data_groups = parse_csv(input_file)
cleaned_groups = clean_data(data_groups)
write_cleaned_csv(output_file, cleaned_groups)

println("Data cleaned and saved to $output_file.")
