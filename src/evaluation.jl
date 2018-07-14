## This file contains mostly meval, infseval.

# Choose infinite or single evaluation.
# The test suite assumes infseval is used.
#doeval(x) = infseval(x)  # infinite evaluation

## export this for users
"""
    symeval(expr::Any)

send `expr` through the Symata evaluation sequence. `expr` is
an `Mxpr` or number, symbol, etc.

In particular, an `Expr` (i.e. not translated to Symata) Symata-evaluated (whic in this case means returned unchanged) by the Symata
evaluation sequence.
"""
symeval(args...) = doeval(args...)

"""
    doeval(expr::Any)

is the main entry point to the Symata evaluation sequence.
"""
function doeval(x)
    if is_throw()
        return x
    end
    return infseval(x)
end

#@inline doeval(x) = meval(x)   # single evaluation

# Enable or disable hashing expressions here.
# We hash expressions so that only unique copies are stored.
# This slows code. It could be faster in some circumstances.
# Eg. if we continue to store the dependent variables of an
# expression as metadata, then we don't need to regenerate them,
# if we find the cached copy of an expression.
#
lcheckhash(x) = x      # do nothing

# We should generate our own  (why did I write this ?)

"""
    get_localized_symbol(s::Symbol)

return a new symbol, like gensym. But, also set `Attribute` `Temporary` for
the new symbol.
"""
function get_localized_symbol(s::Symbol)
    gsym = gensym(string(s))
    set_attribute(gsym, :Temporary)
    return gsym
end

@mkapprule ClearTemporary  nargs => 0

@sjdoc ClearTemporary """
    ClearTemporary()

remove temporary symbols, ie all beginnig with "##", from the symbol table.
"""
# The Temporary attribute is not working. the symbols that escape are just gensysms
@doap function ClearTemporary()
    syms = usersymbols()
    for sym in syms
        ss = string(sym)
#        if length(ss) > 2 && ss[1:2] == "##"
        if  occursin(r"^##", ss)
            delete_sym(Symbol(sym))
        end
    end
    Null
end


@sjdoc Evaluate """
    Evaluate(expr)

specify that `expr` should be evaluated even if it appears as an argument protected by `HoldAll`, etc.

Example:

```
expr = 1 + x^2
f = Compile(Evaluate(expr))
```

!!! note
    `Evaluate` is only implemented for `HoldAll`; not `HoldRest`, etc.
"""

## Mma allows 0 or more args
@mkapprule Evaluate  nodefault => true

# This only handles trivial cases, where Evaluate is not protected by HoldXXX. The cases in which it
# *is* protected are handled below in meval_arguments()
@doap Evaluate(x) = x
@doap Evaluate(args...) = mxpr(:Sequence,args...)
@doap Evaluate() = mxpr(:Sequence)

# @mkapprule Unevaluated
# @doap function Unevaluated(arg)
#     arg
# end

## Macro for translation and evaluation, at repl or from file

# Read a line of user input, translate Expr to Mxpr, but don't evaluate result
macro exnoeval(ex)
    mx = extomx(ex)
    :(($(esc(mx))))
end

# This is called from the REPL
macro ex(ex)   # use this macro from the julia prompt
    mx = symataevaluate(ex)
    :(($(esc(mx))))
end

# The same macro, but we export it for users

"""
    @sym expr

Embed symata expression `expr` in Julia code.

Read and evaluate `expr` embedded in Julia code.

```
julia> a = 1       # Julia symbol `a`
julia> @sym a = 2  # Symata symbol
julia> a
1
julia> @sym a
2
```
"""
macro sym(ex)   # use this macro from the julia prompt
    mx = _sym_inner(ex, EvaluateJuliaSyntaxSimple())
    :(($(esc(mx))))
end

macro symfull(ex) # use this macro for Symata prompt.
    mx = _sym_inner(ex)
    :(($(esc(mx))))
end

function _sym_inner(ex, options=EvaluateJuliaSyntax())
    mx = symataevaluate(ex, options)
    if isa(mx, Symbol)
        mx = QuoteNode(mx)
    end
    return mx
end

# Simply evaluate. Do not print "Out", or count things, etc.
"""
    symtranseval(expr::Any)

translate `expr` from `Expr` to `Mxpr` and send to the top level of the Symata evaluation sequence. `expr`
may also be a number, symbol, string, etc.
"""
function symtranseval(expr)
    symataevaluate(expr, EvaluateJuliaSyntaxSimple())
end

"""
    symparseeval(s::String)

parses `s` into Julia expressions, translates them to Symata expressions, and Symata-evaluates each one,
returning the value returned by the final evaluation.
"""
function symparseeval(s::String)
    mxprs = symparsestring(s)
    local res
    for mx in mxprs
        res = doeval(mx)
    end
    res
end

"""
    macro exsimple(ex::Expr)

translates `ex` to Symata expression and evaluates the result. Most code for interactive sessions disabled.
`@exsimple` is more conventient than `@sym` at the Julia prompt.
"""
macro exsimple(ex)   # use this macro from the julia prompt
    mx = symataevaluate(ex, EvaluateJuliaSyntaxSimple())
    :(($(esc(mx))))
end

"""
    debugmxpr(s::String)

parse and evaluate `s` as a Symata expression. From Julia, this prints the stack trace when an error is raised.
If the same expression entered at the Symata command line, the stack trace will not be printed.
"""
function debugmxpr(s::String)
    symataevaluate(Meta.parse(s))
end

"""
    number_of_Os

is the number of previous outputs to bind to `O`, `OO`, etc.
"""
const number_of_Os = 10

const Os = Array{SJSym}(undef, 0)
for i in 1:number_of_Os
    push!(Os, Symbol("O"^i))
end

# Put this in the System symbol table
# so that they are imported into Global
for i in 1:number_of_Os
    set_system_symval(Os[i], Null)
end


# Bind O to O(n), where n is the most recent line number.
# Bind OO to O(n-1), etc.  When O evaluates to Out(n), the Out rule evaluate
# the expression bound to Out(n).
macro bind_Os()
    expr = Expr(:block)
    for i in 1:number_of_Os
        sym =  string(Os[i])
        newex = :(
                  if (length(Output) - $i + 1) >= 1
                       oexp = mxpr(:Out, get_line_number() - $i + 1)
                       set_system_symval(Meta.parse($sym), oexp)
                       set_sysattributes($sym)
                  end
                     )
        push!(expr.args, newex)
    end
    expr
end

abstract type AbstractEvaluateOptions end

mutable struct EvaluateJuliaSyntax <: AbstractEvaluateOptions
end

function prompt(opt::EvaluateJuliaSyntax)
    # do_we_print_outstring is for IJulia
    if (! simple(opt) ) && isinteractive() && do_we_print_outstring
        print("Out(" * string(get_line_number()) * ") = ")
    end
    nothing
end

simple(opt::EvaluateJuliaSyntax) = false

mutable struct EvaluateJuliaSyntaxSimple <: AbstractEvaluateOptions
end

simple(opt::EvaluateJuliaSyntaxSimple) = true
prompt(opt::EvaluateJuliaSyntaxSimple) = nothing

# """
#     NullExFuncOptions

# options for `symataevaluate` that cut out most of the code for interactive sessions.
# """
# const SimpleExFuncOptions = ExFuncOptions(true)

# """
#     NullExFuncOptions

# options for `symataevaluate` that do not modify its behavior
# """
# const NullExFuncOptions = ExFuncOptions(false)

"""
    symataevaluate(ex::Any, options)

Translate `ex` to Symata and evaluate the result. `ex` is typically an `Expr`,
or else an "elementary" type, such as a `Number` or `String`. If `ex` is already of type `Mxpr`, then
the translation is the identity. `ex` may be an object of any type.
"""
function symataevaluate(ex, options=EvaluateJuliaSyntax())
    if ! simple(options)
        check_doc_query(ex) && return nothing  # Asking for doc? Currently this is:  ?, SomeHead
    end
    res = extomx(ex)  # Translate to Mxpr
    local mx
    if ! simple(options)
        reset_meval_count()
        reset_try_downvalue_count()
        reset_try_upvalue_count()
        if is_timing()  #  && is_sjinteractive()  #  Disallow when reading  code. For now.
            @time mx = trysymataevaluate(res)
            println("tryrule count: downvalue ", get_try_downvalue_count(),", upvalue ", get_try_upvalue_count())
        else
            mx = trysymataevaluate(res)
        end
    else
        mx = trysymataevaluate(res)
    end
    symval(mx) == Null && return nothing
    prompt(options)
    if (! simple(options) ) && isinteractive()  # && is_sjinteractive()
        increment_line_number()
        set_system_symval(:ans,mx)  # Like Julia and matlab, not Mma
        set_symata_prompt(get_line_number())
        if getkerneloptions(:history_length) > 0 push_output(mx) end
        @bind_Os
    end
    if is_throw()
        if is_Mxpr(mx,:Throw)
            @warn("Uncaught Throw")
            clear_throw()
        else
            symwarn("Throw flag set, but expression is not throw.",  mx)
            clear_throw()
            return mx
        end
    end
    return mx
end

function trysymataevaluate(mxin)
    try
        doeval(mxin)
    catch e
        if isa(e,ArgCheckErr)
            @warn(e.msg)
            return mxin
        elseif isa(e,RecursionLimitError)
            @warn(e.msg)
            e.mx
        else
            println(e)
            rethrow(e)  # It would be nice to get better error information.
        end
    end
end


#################################################################################
#                                                                               #
#  infseval                                                                     #
#  repeats meval till we reach a fixed point                                    #
#                                                                               #
#################################################################################

# We use infinite or fixed point evaluation: the Mxpr is evaled repeatedly until it does
# not change. Actually Mma, and Symata try to detect and avoid more evaluations.
# Also try to detect if the expression is simplified, (fixed or canonical).
# This is also complicated by infinite evaluation because whether an expression is
# simplified depends on the current environment. We try to solve this with lists of 'free' symbols.
# Note: lcheckhash is the identity (ie disabled)
# doeval is infseval: ie, we use 'infinite' evaluation. Evaluate till expression does not change.

# We could make this user settable somehow
recursion_limit() =  1024

# Diagnostic. Count number of exits from points in infseval
global const exitcounts = Int[0,0,0,0]

"""
    infseval(mxin::Mxpr)

Apply the evaluation `meval` to `mxin` repeatedly to either a fixed point,
or the recursion limit.
"""
function infseval(mxin::Mxpr)
    if is_throw()
        println("Caught throw at toplevel infseval() for Mxpr")
        return mxin  # TODO check where this test is actually used. We have it in three places
    end
    @mdebug(2, "infseval ", mxin)
    neval = 0
    if checkdirtysyms(mxin)                   # is timestamp on any free symbol in mxin more recent than timestamp on mxin ?
        unsetfixed(mxin)                      # Flag mxin as not being at its fixed point in this environment.
    end                                       # This might be good for iterating over list of args in Mxpr.
    is_fixed(mxin) && return lcheckhash(mxin) # If mxin was already fixed and none of its free vars changed, just return.
    mx = meval(mxin)                          # Do the first evaluation
    if is_Mxpr(mx)
        is_fixed(mx) && return lcheckhash(mx) # The first meval may have set the fixed point flag. Eg, an Mxpr with only numbers, does not need another eval.
        if mx == mxin       # meval did not set fixed flag, but we see that it is at fixed point.
            setfixed(mx)    # They may be equal but we need to set fixed bit in mx !
            setfixed(mxin)  # Do we need to do this to both ?
            return lcheckhash(mx)
        end
    end
    local mx1
    while true              # After 1 eval fixed bit is not set and input not equal to result of first eval
        mx1 = meval(mx)     # So, we do another eval.
        if (is_Mxpr(mx1) && is_fixed(mx1))  || mx1 == mx  # The most recent eval was enough, we are done
            mx = mx1
            break
        end
        neval += 1
        if neval > 10  # Defining Subdivide via Subdivide(a_,b_) := Subdivide(0,a,b), etc. causes neval == 3, which was too many
            setfixed(mx)
            throw(RecursionLimitError("infseval: Too many, $neval, evaluations. Expression still changing", mxprcf(:Hold,mx)))
        end
        mx = mx1
    end
    if is_Mxpr(mx) && mx == mxin
        setfixed(mxin)
        setfixed(mx)
    end
    return lcheckhash(mx)  # checking hash code is disbled.
end

function infseval(qs::Qsym)
    mx = meval(qs)
    return mx == qs ? qs : infseval(mx)
end

function infseval(s::SJSym)
    mx = meval(s)
    return mx == s ? s : infseval(mx)
end
# Any type that other than SJSym (ie Symbol) or Mxpr is not meval'd.
@inline infseval(x) = x
@inline infseval(x::Complex{T}) where {T<:Real} = x.im == zero(x.im) ? x.re : x

infseval(x::Complex{Rational{T}}) where {T<:Integer} = meval(x)
infseval(x::Rational{T}) where {T<:Integer} = meval(x)

meval(x::Float64) = x == Inf ? Infinity : x == -Inf ? MinusInfinity : x

#################################################################################
#                                                                               #
#  meval  Evaluation of Mxpr                                                    #
#  main evaluation routine. Call doeval on head                                 #
#  and some of the arguments. Then apply rules and other things on the result.  #
#                                                                               #
#################################################################################

# These are normally not called, but rather are caught by infseval.
@inline meval(x::Complex{T}) where {T<:Real} = x.im == 0 ? x.re : x
meval(x::Rational{T}) where {T<:Integer} = x.den == 1 ? x.num : x.den == 0 ? ComplexInfinity : x
meval(x::Nothing) = Null
meval(x) = x
meval(s::SJSym) = symval(s) # this is where var subst happens

function meval(qs::Qsym)
    res = symval(qs)
    res
end

function meval(mx::Mxpr)
    increment_meval_count()
    if get_meval_count() > recursion_limit()
        res = mxprcf(:Hold,mx)
        deepsetfixed(res)
        reset_meval_count()
        reset_try_downvalue_count()
        reset_try_upvalue_count()
        throw(RecursionLimitError("Recursion depth of " * string(recursion_limit()) *  " exceeded.", res))
    end
    local ind::String = ""  # some places get complaint that its not defined. other places no !?
    if is_meval_trace()
        ind = " " ^ (get_meval_count() - 1)
        println(ind,">>", get_meval_count(), " " , wrapout(mx))
    end
    nmx::Mxpr = meval_arguments(mx)
    @mdebug(2, "meval: done meval_args ", nmx)
    setfreesyms(nmx,revisesyms(mx)) # set free symbol list in nmx
    @mdebug(2, "meval: done setfreesyms ")
    res = meval_apply_all_rules(nmx)
    @mdebug(2, "meval: done meval_apply_all_rules ", res)
    is_meval_trace() && println(ind,get_meval_count(), "<< ", wrapout(res))
    decrement_meval_count()
    @mdebug(2, "meval: returning ", res)
    return res
end

# ?? why the first test  ! is_canon(nmx). This must apparently always be satisfied.
function meval_apply_all_rules(nmx::Mxpr)
    if  ! is_canon(nmx)
        if isFlat(nmx) nmx = flatten(nmx) end
        if isListable(nmx) nmx = threadlistable(nmx) end
        res = canonexpr!(nmx)
    end
    @mdebug(2, "meval_apply_all_rules: entering apprules: ", res)
    res = apprules(res)           # apply "builtin" rules
    @mdebug(2, "meval_apply_all_rules: exited apprules ", res)
    is_Mxpr(res) || return res
    @mdebug(2, "meval_apply_all_rules: entering ev_upvalues ", res)
    res = ev_upvalues(res)
    @mdebug(2, "meval_apply_all_rules: exited ev_upvalues ", res)
    res = ev_downvalues(res)
    @mdebug(2, "meval_apply_all_rules: entering merge_args_if_empty_syms")
    merge_args_if_emtpy_syms(res) # merge free symbol lists from arguments
    @mdebug(2, "meval_apply_all_rules: exiting")
    return res
end

@inline function argeval(arg)
    if isa(arg,Mxpr{:Unevaluated}) && length(arg) > 0
        ## We may want to strip Unevaluated here, to make it exactly like Mma
        ## But, then it will not prevent Sequence substitution below
        ## And it is not held is some other forms as well.
        ## So, these would need to be fixed.
        return sjcopy(arg)
    else
        return doeval(arg)
    end
end

# Evaluate arguments of mx, construct and return new Mxpr
function meval_arguments(mx::Mxpr)
    nhead = doeval(mhead(mx))
    local nargs::MxprArgs
    mxargs::MxprArgs = margs(mx)
    len::Int = length(mxargs)
    if len == 0
        return mxpr(nhead)
    elseif isHoldFirst(nhead)
        nargs = newargs(len)
        nargs[1] = mxargs[1]
        @inbounds for i in 2:length(mxargs)
            nargs[i] = argeval(mxargs[i])
        end
    elseif isHoldAll(nhead)
        nargs = copy(mxargs)
        for i=1:length(nargs)
            if isa(nargs[i],Mxpr{:Evaluate}) && length(nargs[i]) > 0
                nargs[i] = doeval(nargs[i][1])
            end
        end
    elseif isHoldAllComplete(nhead)
        nargs = copy(mxargs)
    elseif isHoldRest(nhead)
        nargs = copy(mxargs)
        nargs[1] = argeval(nargs[1])
    else      # Evaluate all arguments
        nargs = newargs(len)
        @inbounds for i in 1:len
            nargs[i] = argeval(mxargs[i])
        end
    end
    if  (! isSequenceHold(nhead))  &&  (! isHoldAllComplete(nhead))
        splice_sequences!(nargs)
        len = length(nargs)
    end
    for i=1:len
        if (isa(nargs[i],Mxpr{:Unevaluated}) && length(nargs[i]) > 0) &&
            ! (isHoldAll(nhead) || isHoldAllComplete(nhead))  && !( (isHoldFirst(nhead) && i == 1) || (isHoldRest(nhead) && i > 1))
            nargs[i] = nargs[i][1]
        end
    end
    nmx::Mxpr = mxpr(nhead,nargs)   # new expression with evaled args
end

## We do meval_arguments specially for List, in order to remove occurrances of Nothing
## TODO We probably need to worry about Unevaluated, etc. here.
function meval_arguments(mx::Mxpr{:List})
    nhead = :List
    local nargs::MxprArgs
    mxargs::MxprArgs = margs(mx)
    len::Int = length(mxargs)
    # maybe using this flag is efficient. 'Nothing' is relatively rare.
    got_nothing::Bool = false
    if len == 0
        return mxpr(:List)
    else
        nargs = newargs(len)
        @inbounds for i in 1:len
            nargs[i] = doeval(mxargs[i])
            if nargs[i] == :Nothing
                got_nothing = true
            end
        end
    end
    if got_nothing
        ninds = Array{Int}(undef, 0)
        for i in 1:len
            if nargs[i] == :Nothing
                push!(ninds,i)
            end
        end
        deleteat!(nargs,ninds)
    end
    splice_sequences!(nargs)
    nmx::Mxpr = mxpr(nhead,nargs)   # new expression with evaled args
end

# Similar to checkdirtysyms. The original input Mxpr had a list of free symbols.
# That input has been mevaled at least once and the result is mx, the argument
# to revisesyms. Here, we make a free-symbol list for mx. We look at its current
# free symbol list, which is inherited, and identify those that are no longer
# free. Eg. the environment changed. E.g The user set a = 1. Or 'a' may
# evaluate to an expression with other symbols.
#
# move this to mxpr_type ??
function revisesyms(mx::Mxpr)
    s::FreeSyms = getfreesyms(mx)
    mxage::UInt64 = getage(mx)
    nochange::Bool = true      # Don't create a new symbol list if nothing changed
    for sym in keys(s)         # Check if changes. Does this save or waste time ?
        if symage(sym) > mxage
            nochange = false
            break
        end
    end
    # Need to return a copy here, or Table(x^i + x*i + 1,[i,10]) shows a bug.
    nochange == true && return copy(s)
    nsyms::FreeSyms = newsymsdict()
    for sym in keys(s)
        if symage(sym) > mxage
            mergesyms(nsyms,symval(sym))
        else
            mergesyms(nsyms,sym)  # just copying from the old symbol list
        end
    end
    return nsyms
end

## Try applying downvalues

@inline function ev_downvalues(mx::Mxpr)
    if has_downvalues(mx)
        return applydownvalues(mx)
    else
        return mx
    end
end
@inline ev_downvalues(x) = x

## Applying upvalues. This has to be efficient, we must not iterate over args.
#  Instead, we check free-symbol list.

@inline function ev_upvalues(mx::Mxpr)
    merge_args_if_emtpy_syms(mx) # do upvalues are for free symbols in mx.
    for s in listsyms(mx)
        if has_upvalues(s)
            mx = applyupvalues(mx,s)
            break      # I think we are supposed to only apply one rule
        end
    end
    return mx
end
@inline ev_upvalues(x) = x

## Build list of free syms in Mxpr if list is empty.
@inline function merge_args_if_emtpy_syms(mx::Mxpr)
    if isempty(getfreesyms(mx))    # get free symbol lists from arguments
        mergeargs(mx)              # This is costly if it is not already done.
        add_nothing_if_no_syms(mx) # If there are no symbols, add :nothing, so this is not called again.
    end
end
@inline merge_args_if_emtpy_syms(x) = nothing


#### Thread Listable over Lists

# If any arguments to mx are lists, thread over them. If there are
# more than one list, they must be of the same length.  Eg.
# f([a,b,c],d) -> [f(a,d),f(b,d),f(c,d)].
#
# This is general, but is not the most efficient way. Some Specific
# cases, or classes should be handled separately. Eg Adding two large
# lists of numbers, is slow this way. The problem is that
# threadlistable is called early in the evaluation sequence, as per
# Mma. So we can't add lists of numbers at that point.

function threadlistable(mx::Mxpr)
    pos = Array{Int}(undef, 0)      # FIXME should avoid this
    lenmx = length(mx)
    lenlist::Int = -1
    h = mhead(mx)
    @inbounds for i in 1:lenmx
        if is_Mxpr(mx[i],:List)
            nlen = length(mx[i])
            if lenlist >= 0 && nlen != lenlist
                error("Can't thread over lists of different lengths.")
            end
            lenlist = nlen
            push!(pos,i)
        end
    end
    lenp = length(pos)
    lenp == 0 && return mx      # Nothing to do. return input array
    largs = newargs(lenlist)
    @inbounds for i in 1:lenlist
        nargs = newargs(lenmx)
        p = 1
        @inbounds for j in 1:lenmx
            if p <= lenp && pos[p] == j
                nargs[j] = mx[j][i]
                p += 1
            else
                nargs[j] = mx[j]
            end
        end
        largs[i] = mxpr(h,nargs)
    end
    nmx = mxpr(:List,largs)
    return nmx
end

#### Splice expressions with head Sequence into argument list

## f(a,b,Sequence(c,d),e,f) -> f(a,b,c,d,e,f)
## The following is broken. returns a non-symata object
## FIXME!: f(Sequence([i1,3],[i2,4],[i3,2],[i4,10]))
## No, the sequence is ok. something is broken with Out(n), or ...
## args are args of an Mxpr
function splice_sequences!(args)
    length(args) == 0 && return
    i::Int = 1
    while true
        if is_Mxpr(args[i], :Sequence)
            sargs = margs(args[i])
            splice!(args,i,sargs)
            i += length(sargs)   # skip over new arguments.
        end                      # splicing in lower levels should be done already.
        i += 1
        i > length(args) && break
    end
end
