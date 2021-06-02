# tên file bản đồ
maps = [
    "012-1x2.csv",
    "013-1x2.csv",
    "014-1x2.csv",
    "015-1x2.csv",
    "016-1x2.csv",
    "017-1x2.csv",
    "018-1x2.csv",
    "019-1x2.csv",
    "020-1x2.csv",
]
maps = joinpath.("src", "maps", maps)

# positions
# - :corner
# - :random_c1
# - :random_c2
# - :border
positions = [:corner]

# nb_bph_init
# - bất kì số tự nhiên
nb_bph_inits = [200]

# pr_killed
# - bất kì số thực
pr_killeds = [0.075]

# Đầu vào là tích descartes của những mảng trên
params = map(Iterators.product(maps, nb_bph_inits, pr_killeds, positions)) do (m, n, pr, p)
    (envmap=m, nb_bph_init=n, pr_killed=pr, init_position=p)
end
params = params[:]
