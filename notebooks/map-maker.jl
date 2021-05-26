### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 78e85936-bd55-11eb-23e1-67bc4a4b7901
using Pluto, PlutoUI, ImageFiltering, CairoMakie

# ╔═╡ 96d2bcc8-70c4-436d-888e-3e63a93cf8be
begin
	function generate_map(T::DataType, map_size, flower_width)
		n, m = map_size
		nan = convert(T, NaN)
		s1 = n ÷ 2 - flower_width ÷ 2
		s2 = s1 - flower_width % 2
		crop = [ones(T, s1, m); fill(nan, flower_width, m); ones(T, s2, m)]
		return crop
	end
	function generate_map(T::DataType, msize, fwidth, splits)
		h, w = msize
		nan = convert(T, NaN)
		s1 = (fwidth ÷ splits)^2
		s2 = (h ÷ splits) * (fwidth ÷ splits)
		cases = Iterators.product(1:h, 1:w) |> collect
		p = sortperm(abs.([(m * s1 + n * s2 - fwidth * h) * abs(m - n) for (m, n) in cases])[:])
		cases[p[1:5]]
	end
	generate_map(args...) = generate_map(Float32, args...)
end

# ╔═╡ c7dfd98d-49fa-4d73-bf99-f2cc33878e67
flower_width = @bind flower_width PlutoUI.Slider(10:20, default=15, show_value=true)

# ╔═╡ 5baa737f-005e-4733-8eaf-fdd2643b390e
generate_map((100, 100), flower_width, 3)

# ╔═╡ 6a34a0bf-b66d-4fbe-bb79-ef7b61a03668
begin
	crop = generate_map((100, 100), flower_width);
	count(isnan, crop), prod(size(crop))
end

# ╔═╡ cf84c816-b9d9-40b5-8af6-73e8e265a243
heatmap_kwargs = (
	nan_color=:yellow,
	colorrange = (0, 1),
	colormap = RGBAf0.(0, 1, 0, 0:0.01:1)
	)

# ╔═╡ 8fcf971f-08ff-46c4-9e33-308d6233c0df
heatmap(crop; heatmap_kwargs...)

# ╔═╡ 4e92d1ae-8e86-477d-8de6-fe358cba0721
pr_killed = imfilter(isnan.(crop) .* 0.2, Kernel.gaussian(3));

# ╔═╡ 4b8a5719-2832-48f2-9dbd-e1009bccdd61
heatmap(pr_killed)

# ╔═╡ Cell order:
# ╠═78e85936-bd55-11eb-23e1-67bc4a4b7901
# ╠═96d2bcc8-70c4-436d-888e-3e63a93cf8be
# ╠═c7dfd98d-49fa-4d73-bf99-f2cc33878e67
# ╠═5baa737f-005e-4733-8eaf-fdd2643b390e
# ╠═6a34a0bf-b66d-4fbe-bb79-ef7b61a03668
# ╠═cf84c816-b9d9-40b5-8af6-73e8e265a243
# ╠═8fcf971f-08ff-46c4-9e33-308d6233c0df
# ╠═4e92d1ae-8e86-477d-8de6-fe358cba0721
# ╠═4b8a5719-2832-48f2-9dbd-e1009bccdd61
