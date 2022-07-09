JULIAVER=julia-1.8.0-rc1
deps:
	wget https://julialang-s3.julialang.org/bin/linux/x64/1.8/$(JULIAVER)-linux-x86_64.tar.gz -O julia.tar.gz
	tar xvf julia.tar.gz
	ln -s $(JULIAVER)/bin/julia -f /usr/local/bin/julia
	julia --project -e 'using Pkg; Pkg.instantiate()'

test:
	julia --project -e "using Pkg; Pkg.test()"
