"""
    Slices{P,SM,AX,S,N} <: AbstractArray{S,N}

An `AbstractArray` of slices into a parent array.

These should typically be constructed by [`eachslice`](@ref), [`eachcol`](@ref) or
[`eachrow`](@ref).

[`parent(S::Slices)`](@ref) will return the parent array.
"""
struct Slices{P,SM,AX,S,N} <: AbstractArray{S,N}
    """
    Parent array
    """
    parent::P
    """
    A tuple of length `ndims(parent)`, denoting how each dimension should be handled:
      - an integer `i`: this is the `i`th dimension of the outer `Slices` object.
      - `:`: an "inner" dimension
    """
    slicemap::SM
    """
    A tuple of length `N` containing the [`axes`](@ref) of the `Slices` object.
    """
    axes::AX
end

unitaxis(::AbstractArray) = Base.OneTo(1)

function Slices(A::P, slicemap::SM, ax::AX) where {P,SM,AX}
    N = length(ax)
    S = Base._return_type(view, Tuple{P, map((a,l) -> l === (:) ? Colon : eltype(a), axes(A), slicemap)...})
    Slices{P,SM,AX,S,N}(A, slicemap, ax)
end

_slice_check_dims(N) = nothing
function _slice_check_dims(N, dim, dims...)
    1 <= dim <= N || throw(DimensionMismatch("Invalid dimension $dim"))
    dim in dims && throw(DimensionMismatch("Dimensions $dims are not unique"))
    _slice_check_dims(N,dims...)
end

@inline function _eachslice(A::AbstractArray{T,N}, dims::NTuple{M,Integer}, drop::Bool) where {T,N,M}
    _slice_check_dims(N,dims...)
    if drop
        # if N = 4, dims = (3,1) then
        # axes = (axes(A,3), axes(A,1))
        # slicemap = (2, :, 1, :)
        ax = map(dim -> axes(A,dim), dims)
        slicemap = ntuple(dim -> something(findfirst(isequal(dim), dims), (:)), N)
        return Slices(A, slicemap, ax)
    else
        # if N = 4, dims = (3,1) then
        # axes = (axes(A,1), OneTo(1), axes(A,3), OneTo(1))
        # slicemap = (1, :, 3, :)
        ax = ntuple(dim -> dim in dims ? axes(A,dim) : unitaxis(A), N)
        slicemap = ntuple(dim -> dim in dims ? dim : (:), N)
        return Slices(A, slicemap, ax)
    end
end
@inline function _eachslice(A::AbstractArray, dim::Integer, drop::Bool)
    _eachslice(A, (dim,), drop)
end

"""
    eachslice(A::AbstractArray; dims, drop=true)

Create a [`Slices`](@ref) object that is an array of slices over dimensions `dims` of `A`, returning
views that select all the data from the other dimensions in `A`. `dims` can either by an
integer or a tuple of integers.

If `drop = true` (the default), the outer `Slices` will drop the inner dimensions, and
the ordering of the dimensions will match those in `dims`. If `drop = false`, then the
`Slices` will have the same dimensionality as the underlying array, with inner
dimensions having size 1.

See also [`eachrow`](@ref), [`eachcol`](@ref), and [`selectdim`](@ref).

!!! compat "Julia 1.1"
     This function requires at least Julia 1.1.

!!! compat "Julia 1.7"
     Prior to Julia 1.7, this returned an iterator, and only a single dimension `dims` was supported.

# Example

```jldoctest
julia> M = [1 2 3; 4 5 6; 7 8 9]
3×3 Matrix{Int64}:
 1  2  3
 4  5  6
 7  8  9

julia> S = eachslice(M, dims=1)
3-element Rows{Matrix{Int64}, Tuple{Base.OneTo{Int64}}, SubArray{Int64, 1, Matrix{Int64}, Tuple{Int64, Base.Slice{Base.OneTo{Int64}}}, true}}:
 [1, 2, 3]
 [4, 5, 6]
 [7, 8, 9]

julia> S[1]
3-element view(::Matrix{Int64}, 1, :) with eltype Int64:
 1
 2
 3

julia> T = eachslice(M, dims=1, drop=false)
3×1 Slices{Matrix{Int64}, Tuple{Int64, Colon}, Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}, SubArray{Int64, 1, Matrix{Int64}, Tuple{Int64, Base.Slice{Base.OneTo{Int64}}}, true}, 2}:
 [1, 2, 3]
 [4, 5, 6]
 [7, 8, 9]
```
"""
@inline function eachslice(A; dims, drop=true)
    _eachslice(A, dims, drop)
end

"""
    eachrow(A::AbstractVecOrMat) <: AbstractVector

Create a [`Rows`](@ref) object that is a vector of rows of matrix or vector `A`.
Row slices are returned as `AbstractVector` views of `A`.

See also [`eachcol`](@ref) and [`eachslice`](@ref).

!!! compat "Julia 1.1"
     This function requires at least Julia 1.1.

!!! compat "Julia 1.7"
     Prior to Julia 1.7, this returned an iterator.

# Example

```jldoctest
julia> a = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> S = eachrow(a)
2-element Rows{Matrix{Int64}, Tuple{Base.OneTo{Int64}}, SubArray{Int64, 1, Matrix{Int64}, Tuple{Int64, Base.Slice{Base.OneTo{Int64}}}, true}}:
 [1, 2]
 [3, 4]

julia> S[1]
2-element view(::Matrix{Int64}, 1, :) with eltype Int64:
 1
 2
```
"""
eachrow(A::AbstractMatrix) = _eachslice(A, (1,), true)
eachrow(A::AbstractVector) = eachrow(reshape(A, size(A,1), 1))

"""
    eachcol(A::AbstractVecOrMat) <: AbstractVector

Create a [`Columns`](@ref) object that is a vector of columns of matrix or vector `A`.
Column slices are returned as `AbstractVector` views of `A`.

See also [`eachrow`](@ref) and [`eachslice`](@ref).

!!! compat "Julia 1.1"
     This function requires at least Julia 1.1.

!!! compat "Julia 1.7"
     Prior to Julia 1.7, this returned an iterator.

# Example

```jldoctest
julia> a = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> S = eachcol(a)
2-element Columns{Matrix{Int64}, Tuple{Base.OneTo{Int64}}, SubArray{Int64, 1, Matrix{Int64}, Tuple{Base.Slice{Base.OneTo{Int64}}, Int64}, true}}:
 [1, 3]
 [2, 4]

julia> S[1]
2-element view(::Matrix{Int64}, :, 1) with eltype Int64:
 1
 3
```
"""
eachcol(A::AbstractMatrix) = _eachslice(A, (2,), true)
eachcol(A::AbstractVector) = eachcol(reshape(A, size(A, 1), 1))

"""
    Rows{M,AX,S}

A special case of [`Slices`](@ref) that is a vector of row slices of a matrix, as
constructed by [`eachrow`](@ref).

[`parent(S)`](@ref) can be used to get the underlying matrix.
"""
const Rows{P<:AbstractMatrix,AX,S<:AbstractVector} = Slices{P,Tuple{Int,Colon},AX,S,1}

"""
    Columns{M,AX,S}

A special case of [`Slices`](@ref) that is a vector of column slices of a matrix, as
constructed by [`eachcol`](@ref).

[`parent(S)`](@ref) can be used to get the underlying matrix.
"""
const Columns{P<:AbstractMatrix,AX,S<:AbstractVector} = Slices{P,Tuple{Colon,Int},AX,S,1}


IteratorSize(::Type{Slices{P,SM,AX,S,N}}) where {P,SM,AX,S,N} = HasShape{N}()
axes(s::Slices) = s.axes
size(s::Slices) = map(length, s.axes)

@inline function _slice_index(s::Slices, c...)
    return map(l -> l === (:) ? (:) : c[l], s.slicemap)
end

getindex(s::Slices{P,SM,AX,S,N}, I::Vararg{Int,N}) where {P,SM,AX,S,N} =
    view(s.parent, _slice_index(s, I...)...)
setindex!(s::Slices{P,SM,AX,S,N}, val, I::Vararg{Int,N}) where {P,SM,AX,S,N} =
    s.parent[_slice_index(s, I...)...] = val

parent(s::Slices) = s.parent
