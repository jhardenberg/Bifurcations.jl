module Bazykin85

using DiffEqBase: ODEProblem
using Parameters: @with_kw, @unpack
using StaticArrays: SVector
using Setfield: @lens
import Setfield

using ...Bifurcations: BifurcationProblem

@with_kw struct Bazykin85Param{A, E, G, D}
    α::A = 0.1
    ϵ::E = 0.01  # ≪ 1 ?
    γ::G = 1.0
    δ::D = 0.1
end


function f(x::SVector, p, t)
    @unpack α, ϵ, γ, δ = p
    return SVector(
             x[1] - x[1] * x[2] / (1 + α * x[1]) - ϵ * x[1]^2,
        -γ * x[2] + x[1] * x[2] / (1 + α * x[1]) - δ * x[2]^2,
    )
end


make_prob(
        p = Bazykin85Param();
        u0 = SVector(1 / p.ϵ, 0.0),
        tspan = (0.0, 30.0),
        ode = ODEProblem(f, u0, tspan, p),
        param_axis = (@lens _.α),
        t_domain = (0.01, 1.5),
        kwargs...) =
    BifurcationProblem(ode, param_axis, t_domain;
                       phase_space = (SVector(-0.1, -0.1),  # u_min
                                      SVector(Inf, Inf)),   # u_max
                       kwargs...)

prob = make_prob()
ode = prob.p.de_prob
param_axis = prob.p.param_axis
t_domain = prob.t_domain

end  # module
