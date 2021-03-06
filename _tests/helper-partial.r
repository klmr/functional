has_formals = function (...) {
    f_to_s = function (formals) {
        if (length(formals) == 0)
            return('')
        values = lapply(formals, deparse, backtick = TRUE)
        names = lapply(sapply(names(formals), as.name), as.character)
        paste(mapply(paste, names, values, sep = ' = '), collapse = ', ')
    }

    expected = as.pairlist(as.list(sys.call())[-1])
    function (actual)
        expect(identical(formals(actual), expected),
               sprintf('formals mismatch (expected (%s), got (%s))',
                       f_to_s(expected), f_to_s(formals(actual))),
               'formals match')
}

prints = function (expected) {
    function (actual) {
        printed = paste(capture.output(actual), collapse = '\n')
        expect(identical(printed, expected),
               sprintf('does not print %s (got %s)',
                       dQuote(expected), dQuote(printed)),
               'printed correctly')
    }
}

prints_some = function (expected) {
    function (actual) {
        printed = paste(capture.output(actual), collapse = '\n')
        expect(grepl(expected, printed, perl = TRUE),
               sprintf('does not print %s (got %s)',
                       dQuote(expected), dQuote(printed)),
               'printed correctly')
    }
}
