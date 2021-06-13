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
    "12-3x3.csv",
    "13-3x3.csv",
    "14-3x3.csv",
    "15-3x3.csv",
    "16-3x3.csv",
    "17-3x3.csv",
    "18-3x3.csv",
    "19-3x3.csv",
    "20-3x3.csv",
]
maps = joinpath.("src", "maps", maps)

# positions
# - :corner
# - :random_c1
# - :random_c2
# - :border
positions = [:corner, :border]

# nb_bph_init
# - bất kì số tự nhiên
nb_bph_inits = [200, 20]

# pr_killed
# - bất kì số thực
pr_killeds = [0.075, 0.09, 0.12, 0.15]

# Đầu vào là tích descartes của những mảng trên
params1 = map(Iterators.product(maps, nb_bph_inits, pr_killeds, positions)) do (m, n, pr, p)
    (envmap=m, nb_bph_init=n, pr_killed=pr, init_position=p)
end
params1 = params1[:]

const no_flower_map = joinpath("src", "maps", "no-flower.csv")
const params2 = [
    (envmap=no_flower_map, pr_killed=0.15, nb_bph_init=20, init_position=:corner),
    (envmap=no_flower_map, pr_killed=0.15, nb_bph_init=200, init_position=:corner),
    (envmap=no_flower_map, pr_killed=0.15, nb_bph_init=20, init_position=:border),
    (envmap=no_flower_map, pr_killed=0.15, nb_bph_init=200, init_position=:border),
]

const params3 = let maps = ["019-1x2.csv", "19-3x3.csv"]
    local p = map(Iterators.product(maps, nb_bph_inits, positions)) do (envmap, n, p)
        (envmap=joinpath("src", "maps", envmap), pr_killed=0.0, nb_bph_init=n, init_position=p)
    end
    collect(p)[:]
end

params = [params1; params2; params3]
