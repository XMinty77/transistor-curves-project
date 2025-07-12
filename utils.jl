function roll!(arr::Vector, val)
    push!(arr, val)
    popfirst!(arr)
    return arr
end

const CONVERT_MAX_MEASURE = 1024;
const CONVERT_MAX_VDD = 1024;
const CONVERT_RC = 1;
const CONVERT_RB = 1;

function convert_ib(vrb)
    return convert_voltage(vrb) / CONVERT_RB
end

function convert_ic(vrc)
    return convert_voltage(vrc) / CONVERT_RC
end

function convert_voltage(voltage)
    return voltage * CONVERT_MAX_VDD / CONVERT_MAX_MEASURE
end

function deconvert_voltage(voltage)
    return voltage * CONVERT_MAX_VDD / CONVERT_MAX_MEASURE
end