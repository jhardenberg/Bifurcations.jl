using Parameters: @with_kw

calc_direction(_u, J, _L, Q) = det(vcat(J, (@view Q[end:end, :])))
# Q[:, end] --- tangent w/o det-fixing

find_simple_bifurcation!(cache, opts, sbint) =
    find_simple_bifurcation!(cache, opts, sbint.u0, sbint.u1,
                             sbint.direction)

find_simple_bifurcation!(cache, opts, args...) =
    find_zero!(cache, opts, calc_direction, args...)

@with_kw struct FindZeroInputError <: Exception
    f0
    f1
    u0
    u1
    f
end

Base.showerror(io::IO, e::FindZeroInputError) = print(io, """
Test function `f` evaluated at `u0` and `u1` have the same sign.
f0 = $(e.f0)
f1 = $(e.f1)
u0 = $(e.u0)
u1 = $(e.u1)
f = $(e.f)
""")

function find_zero!(cache, opts, f, u0, u1, direction)
    prob_cache = cache.prob_cache
    H = cache.H
    J = cache.J
    Q = cache.Q
    rtol = opts.rtol
    atol = opts.atol

    H, J = residual_jacobian!(H, J, u1, prob_cache)
    A = vcat(J, _zeros(J, 1, size(J, 2)))  # TODO: improve
    L, Q = lq!(Q, A)
    f1 = f(u1, J, L, Q)

    H, J = residual_jacobian!(H, J, u0, prob_cache)
    A = vcat(J, _zeros(J, 1, size(J, 2)))  # TODO: improve
    L, Q = lq!(Q, A)
    tJ = tangent(L, Q)
    f0 = f(u0, J, L, Q)

    if f0 * f1 > 0
        throw(FindZeroInputError(f0, f1, u0, u1, f))
    end

    fu = f0
    u = u0
    h = norm(u0 .- u1) / 2
    for _ in 1:opts.max_adaptations
        # predictor
        v = u .+ direction * h .* tJ

        # corrector
        for _ in 1:opts.max_corrector_steps
            w, _, H, L, Q, J = corrector_step!(H, J, Q, v, prob_cache)
            if isalmostzero(H, rtol, atol)
                cache.corrector_success = true
                @goto corrector_success
            end
            v = w
        end
        error("corrector failed")

        @label corrector_success
        tJv = tangent(L, Q)
        fv = f(v, J, L, Q)
        @assert all(isfinite.(v))

        # secant
        h = - fv / (fv - fu) * h
        u = v
        fu = fv

        if abs(h) < opts.h_zero
            return v, tJv, L, Q, J
        end

        if tJ ⋅ tJv < 0
            direction *= -1
        end
        tJ = tJv
    end
    error("zero not found")
end
