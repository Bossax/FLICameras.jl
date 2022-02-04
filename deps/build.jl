module BuildingTaoBindings

using Libdl

TAO_INCDIR = get(ENV, "TAO_INCDIR", "/home/narit/local/TAO/base")
TAO_LIBDIR = get(ENV, "TAO_LIBDIR", "/usr/local/lib")
TAO_DLL = joinpath(TAO_LIBDIR, "libtao.$(Libdl.dlext)")

run(`make TAO_INCDIR="$TAO_INCDIR" TAO_LIBDIR="$TAO_LIBDIR" TAO_DLL="$TAO_DLL" all`)

end # module
