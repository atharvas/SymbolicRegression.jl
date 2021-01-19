using Optim

# Proxy function for optimization
function optFunc(x::AbstractArray{T, 1}, X::AbstractArray{T, 2},
                 y::AbstractArray{T, 1}, baseline::T,
                 tree::Node, options::Options)::Float32 where {T<:AbstractFloat}
    setConstants(tree, x)
    return scoreFunc(X, y, baseline, tree, options)
end

# Use Nelder-Mead to optimize the constants in an equation
function optimizeConstants(X::AbstractArray{T, 2}, y::AbstractArray{T, 1},
                           baseline::T, member::PopMember{T},
                           options::Options)::PopMember{T} where {T<:AbstractFloat}

    nconst = countConstants(member.tree)
    if nconst == 0
        return member
    end
    x0 = getConstants(member.tree)
    f(x::AbstractArray{T, 1})::T = optFunc(x, X, y, baseline, member.tree, options)
    if size(x0)[1] == 1
        algorithm = Newton
    else
        algorithm = NelderMead
    end

    try
        result = optimize(f, x0, algorithm(), Optim.Options(iterations=100))
        # Try other initial conditions:
        for i=1:options.nrestarts
            new_start = x0 .* (convert(T, 1.0) .+ convert(T, 0.5)*randn(T, size(x0)[1]))
            tmpresult = optimize(f, new_start, algorithm(), Optim.Options(iterations=100))

            if tmpresult.minimum < result.minimum
                result = tmpresult
            end
        end

        if Optim.converged(result)
            setConstants(member.tree, result.minimizer)
            member.score = convert(T, result.minimum)
            member.birth = getTime()
        else
            setConstants(member.tree, x0)
        end
    catch error
        # Fine if optimization encountered domain error, just return x0
        if isa(error, AssertionError)
            setConstants(member.tree, x0)
        else
            throw(error)
        end
    end
    return member
end
