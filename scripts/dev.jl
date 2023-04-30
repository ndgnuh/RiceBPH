using CSV
using DataFrames
using RiceBPH.MyProtoBuf

const df = CSV.read("./ofaat-nums-bph-init.csv", DataFrame)

const pb = MyProtoBuf.from_dataframe(df)
@show pb
