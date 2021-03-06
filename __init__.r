#' Create a closure over a given environment for the specified formals and body.
#'
#' Helper function to facilitate the creation of functions from quoted
#' expressions at runtime.
#'
#' @param formals list of formal arguments; list names correspond to parameter
#'  names, list values correspond to quoted parameter defaults
#' @param body quoted expression to use as function body
#' @param env the environment in which to define the function
#' @return A function defined in \code{env}.
#'
#' @examples
#' x = new.env()
#' closure(list(a = quote(expr = )), call('+', quote(a), 1), x)
#' # function (a)
#' # a + 1
#' # <environment: 0x7feec6390b8>
#' @export
closure = function (formals, body, env)
    eval(call('function', as.pairlist(formals), body), env)

#' Partial function application
#'
#' \code{partial} (and \code{p}, if shortcuts aren’t disabled) apply a function
#' partially over some arguments.
#'
#' @param f a function
#' @param ... partial arguments to the function \code{f}; these can be named or
#' positional, but not a mix of both
#' @return A function like \code{f}, with the provided arguments bound to
#' \code{f}’s parameters, and having as parameters the remaining, un-specified
#' arguments.
#'
#' @details
#' \code{partial(f, ...)} will create a new function with the same semantics as
#' \code{f}, but with some of its parameters (re-)bound to values. The resulting
#' function is the same as the original, but its arguments are now bound to the
#' specified default values. Named values are matched against their (full, not
#' partial) argument names. Unnamed arguments are matched against the arguments
#' by their position, starting at the second; the first argument remains free.
#' To bind to the first argument, use named arguments.
#'
#' @note Creating a partial function application with no fixed arguments is
#' valid, and just yields the original function. Creating a partial function
#' where all arguments are fixed is also valid, but may yield a partially
#' applied function with misleading signature.
#' @note \code{partial} applies the arguments in a different order to the
#' (somewhat misnamed) \code{\link{functional::Curry}}. See \link{Examples} for
#' a comparison.
#' @note \code{p} is defined as a handy shortcut for \code{partial}, since the
#' purpose of \code{partial} is explicitly to allow concise code. The definition
#' of this shortcut can be disabled by setting the R option
#' \code{klmr.disable_shortcuts} to \code{TRUE}.
#' @note \code{partial} might not work as expected with functions that access
#' their arguments via \code{match.call()} or similar indirect methods. For
#' instance, \code{partial(lm, data = …)(formula)} will fail because the data is
#' not passed on to the actual model building function. The same is true for S3
#' methods. See examples for an illustration.
#'
#' @examples
#' # Use partial application to create a function which adds 5 to its argument
#'
#' add5 = partial(`+`, 5)
#' # alternatively:
#' \dontrun{add5 = p(`+`, 5)}
#'
#' add5(1 : 4)
#' # [1] 6 7 8 9
#'
#' # `partial` works differently from `functional::Curry`:
#'
#' partial(`-`, 1)(10)
#' # [1] 9
#'
#' \dontrun{functional::Curry(`-`, 1)(10)}
#' # [1] -9
#'
#' # S3 dispatch fails:
#'
#' # Wrong result:
#' partial(print, digits = 2)(1.234)
#' # Explicitly specifying the generic method works:
#' partial(print.default, digits = 2)(1.234)
#' @export
partial = function (f, ...) {
    # We capture arguments unevaluated. I am not entirely sure where this would
    # make a difference, but it’s the most conservative choice because it
    # approximates the original call as closely as possible.
    fixed = match.call(expand.dots = FALSE)$...

    if (length(fixed) == 0)
        return(f)

    if (is.primitive(match.fun(f))) {
        # None of what we do below works with primitives. Don’t try to be smart
        # with primitive functions, otherwise things stop working. For instance,
        # consider named arguments with primitives, such as `na.rm` with `sum`.
        name = deparse(substitute(f))
        closure(alist(... = ),
                bquote(base::do.call(.Primitive(.(name)),
                                     base::c(base::list(...), .(fixed)))),
                globalenv())
    } else {
        if (is.name(substitute(f)) && is.function(f)) {
            # Might as well have a prettier rendering of the resulting function.
            formals = formals(f)
            env = environment(f)
            f = substitute(f)
        } else {
            f = match.fun(f)
            env = environment(f)
            formals = formals(f)
        }

        # Ensure that all arguments are either positional or named, because
        # correctly handling a mix is painful.
        names = names(fixed)
        if (! is.null(names) && any(names == ''))
            stop(paste0(dQuote('partial'), ' does not support mixing named and',
                        ' unnamed arguments except for primitive functions'))

        # If positional arguments were given, fill call from left to right,
        # after first argument.
        bound_names = names %||% 2 : (1 + length(fixed))
        all_names = if (is.null(names)) seq_along(formals) else names(formals)
        # This handles fixed arguments in `...` correctly!
        formals = formals[setdiff(all_names, bound_names)]

        closure(formals,
                bquote(do.call(.(f), c(as.list(match.call()[-1]), .(fixed)),
                               envir = parent.frame())),
                env)
    }
}

#' Test whether a value is “falsy”.
#'
#' \code{is_false(x)} tests whether \code{x} is a falsy value.
#' @param x the object to be tested
#' @return Returns either \code{TRUE} or \code{FALSE}, depending on whether
#' \code{x} is falsy.
#'
#' @details
#' An object is considered “falsy” when it is either the single value
#' \code{FALSE} or no value at all, i.e. \code{NULL} / a vector of length 0.
#' @export
is_false = function (x)
    identical(as.vector(x), FALSE) || length(x) == 0

#' Fall back to an alternative value if none given
#'
#' \code{a \%||\% b} evaluates to \code{a} unless \code{a} is falsy, in which
#' case it evaluates to \code{b}.
#' @param value the value
#' @param alternative an alternative value
#' @return Returns \code{value}, unless it isn’t a value, or \code{FALSE}, in
#' which case \code{alternative} is returned.
#' @seealso is_false
#' @export
`%||%` = function (value, alternative)
    if(is_false(value)) alternative else value

# FIXME: Add vectorized variant `%|%`, and `%or%`, which also handles empty
# strings and errors.

#' Compose functions \code{g} and \code{f}.
#'
#' @param g a function taking as its argument the return value from \code{f}
#' @param f a function with arbitrary arguments
#' @return A fuction which takes the same arguments as \code{f} and returns the
#' same return type as \code{g}
#'
#' @note Functions are applied in the inverse order of
#' \code{\link{functional::Compose}}:
#' \url{http://tolstoy.newcastle.edu.au/R/e9/help/10/02/4529.html}
#'
#' @note The semantics of \code{compose} are given by the equivalence
#' \code{compose(g, f)(...) = g(f(...))}.
#'
#' @note All three forms of this function (\code{compose}, \code{\%.\%} and
#' \code{\%|>\%}) are exactly identical. The only difference is the order of the
#' arguments, which is reversed in \code{\%|>\%}. \code{\%|>\%} is thus the
#' higher-order function counterpart to \code{\link{\%>\%}}.
#' @export
compose = function (g, f) {
    force(f)
    force(g)
    function (...) g(f(...))
}

#' @rdname compose
#' @export
`%.%` = compose

#' @rdname compose
#' @export
`%|>%` = function (f, g) compose(g, f)

#' Pipe operator like in F#, Bash …
#' @seealso \code{\link{magrittr::\%>\%}}
#' @export
box::use(magrittr[`%>%`])

#' Argument matching with defaults
#'
#' \code{match_call_defaults} operates similar to \code{\link{match.call}}, but
#' considers also unset arguments for which defaults exist.
#'
#' @param call an unevaluated call to a function, as generated by
#'  \code{\link{call}}
#' @param .formals the formal argument definition of \code{call}
#' @return \code{match_call_defaults} returns a \code{call} corresponding to
#' the \code{call} argument, whose missing values have been filled in by the
#' defaults provided by \code{.formals}; the arguments are unevaluated.
#' @details
#' Both \code{call} and \code{.formals} have defaults which refer to the
#' function from which \code{match_call_defaults} was invoked. Thus, in normal
#' usage no arguments are specified.
#'
#' The function is useful to forward a call to a different function, when most
#' arguments remain unchanged. See examples.
#'
#' @examples
#' paste_csv = function (..., sep = ',', collapse = NULL) {
#'     call = base$match_call_defaults()
#'     call[[1]] = quote(paste)
#'     eval.parent(call)
#' }
#'
#' paste_csv('a', 'test') # => "a,test"
#' paste_csv('a', 'test', sep = ';') # => "a;test"
#' @export
match_call_defaults = function (
    call = match.call(sys.function(sys.parent()), sys.call(sys.parent())),
    .formals = formals(sys.function(sys.parent()))
) {
    .formals = .formals[names(.formals) != '...']
    missing = is.na(match(names(.formals), names(call)))
    missing_names = names(.formals)[missing]
    missing_values = .formals[missing]
    call[missing_names] = missing_values
    call
}

#' \code{substitute_call} takes an unevaluated \code{call} object and evaluates
#' all its argument, as well as the function name, to produce a standalone
#' \code{call} object that no longer relies on its current context.
#' @param envir the environment to evaluate the call in
#' @return \code{substitute_call} returns a \code{call} object with its
#' arguments evaluated.
#' @examples
#' # Show the difference between `match_call_defaults` and `substitute_call`
#' f = function (x) match_call_defaults()
#' g = function (x) substitute_call()
#' f(1 + 2) # => f(x = 1 + 2)
#' g(1 + 2) # => (function (x) substitute_call())(x = 3)
#' @rdname match_call_defaults
substitute_call = function (
    call = match_call_defaults(
        call = match.call(sys.function(sys.parent()), sys.call(sys.parent())),
        .formals = formals(sys.function(sys.parent()))
    ),
    envir = parent.frame()
) {
    call[] = lapply(call, eval, envir = envir)
    call
}
