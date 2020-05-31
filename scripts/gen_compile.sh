#!/bin/sh

## Create a Julia image with Symata precompiled.
## The precompilation statements are generated by the Symata test suite.

## See documentation for PackageCompiler for an explanation of the code below.
## After generating symataimage.so, run the image with
## > julia -J symataimage.so
## You have to call `run_repl()` before entering the repl with the `=` character

IMAGE=symataimage.so
PRECOMPILE=symata_precompile.jl

julia --trace-compile="${PRECOMPILE}" -e "using Symata; Symata.run_testsuite(); Symata.setkerneloptions(:bigint_input, true); Symata.run_testsuite()"

julia -e "using PackageCompiler; PackageCompiler.create_sysimage(:Symata; precompile_statements_file=\"${PRECOMPILE}\", sysimage_path=\"${IMAGE}\", replace_default=false)"