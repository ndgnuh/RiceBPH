function format_item(s::String; kw...)
    return s
end
function format_item(s::AbstractFloat)
    if isnothing(digits)
        return s
    else
        return @sprintf "%.04f" s
    end
end

function to_latex_table(df)
    # Convert to latex
    df = format_item.(df)
    s = strip(latextabular(df))

    # Replace column headers
    lines = split(s, "\n")
    theads = map(names(df)) do name
        "\\textbf{$(name)}"
    end
    lines[2] = join(theads, " &") * "\\\\"

    # Join with hlines
    join(lines, "\n\\hline\n")
end
