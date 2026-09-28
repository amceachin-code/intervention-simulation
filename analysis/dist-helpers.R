## Distribution helpers shared by 01-simulations.R and its tests. Extracted
## so group_cdf, the only distributional assumption in the simulation pipeline, has
## unit tests independent of the API and the committed CSVs.

## P(score <= x) for a group described by published percentiles.
## Linear interpolation between published percentiles; below the lowest (P10)
## the left tail is extrapolated with a normal fitted through P10 and P25.
## That extrapolation is the ONLY distributional assumption in this script;
## the reconstructed-mass column in Table E is the check on it.
group_cdf <- function(pcts, x) {
  p <- sort(as.integer(names(pcts))); v <- unname(pcts[as.character(p)])
  o <- order(v); p <- p[o]; v <- v[o]
  ## Strict >: at exactly the top knot the interior loop returns that knot's
  ## own percentile. Using >= here would jump to 1.0 at P90.
  ## Only called at p10/p25 cuts today (validated there); the right tail above
  ## the top knot has no fitted extrapolation, so a cut landing above it is a
  ## caller error worth surfacing rather than silently returning 1.
  if (x > v[length(v)])
    stop("group_cdf: x=", x, " is above the top knot (", v[length(v)],
         "); no right-tail extrapolation is implemented")
  if (x <= v[1]) {
    sd <- (v[2]-v[1]) / (qnorm(p[2]/100) - qnorm(p[1]/100))
    ## Tied knots (a subgroup reporting the same value at two percentiles,
    ## e.g. a floor effect) give sd == 0 and pnorm(Inf-ish/0) == NaN, which
    ## would silently propagate into mass/total/share_of_tail downstream.
    if (!is.finite(sd) || sd <= 0)
      stop("group_cdf: non-finite or non-positive left-tail sd (", sd,
           ") from tied percentile knots p", p[1], "=p", p[2], "=", v[1])
    mu <- v[1] - qnorm(p[1]/100)*sd
    return(pnorm((x-mu)/sd))
  }
  for (i in seq_len(length(v)-1)) {
    if (x >= v[i] && x <= v[i+1])
      return((p[i] + (p[i+1]-p[i])*(x-v[i])/(v[i+1]-v[i]))/100)
  }
  1
}
