#' Format statistics (APA 6th edition)
#'
#' Takes \code{htest} objects from various statistical methods to create
#' formated chraracter strings to report the results in accordance with APA manuscript guidelines.
#'
#' @param x \code{htest} object. See details.
#' @param stat_name Character. If \code{NULL} (default) the name given in \code{x} (or a formally correct
#'    adaptation, such as \eqn{r_S} instead of "rho") is used, otherwise the name is overwritten by the one
#'    supplied. See details.
#' @param n Numeric. Size of the sample; required when reporting \eqn{\chi^2} tests, otherwise this parameter
#'    is ignored.
#' @param ci Numeric. If \code{NULL} (default) the function tries to obtain confidence intervals from \code{x}.
#'    Other confidence intervals can be supplied as a \code{vector} of length 2 (lower and upper boundary, respectively)
#'    with attribute \code{conf.level}, e.g., bootstrapped confidence intervals.
#' @param in_paren Logical. Indicates if the formated string will be reported inside parentheses. See details.
#' @param ... Additional arguments passed to or from other methods.
#' @details The function should work on a wide range of \code{htest} objects. Due to the large number of functions
#'    that produce these objects and their idiosyncracies, the produced strings may sometimes be inaccurate. If you
#'    experience inaccuracies you may report these \href{https://github.com/crsh/papaja/issues}{here} (please include
#'    a reproducible example in your report!).
#'
#'    \code{stat_name} is placed in the output string and is thus passed to pandoc or LaTeX through \pkg{kntir}.
#'    Thus, to the extent it is supported by the final document type, you can pass LaTeX-markup to format the final
#'    text (e.g., \code{\\\\tau} yields \eqn{\tau}).
#'
#'    If \code{in_paren} is \code{TRUE} parentheses in the formated string, such as those surrounding degrees
#'    of freedom, are replaced with brackets.
#'
#' @return \code{apa_print()} returns a list containing the following components according to the input:
#'
#'    \describe{
#'      \item{\code{stat}}{A character string giving the test statistic, parameters (e.g., degrees of freedom),
#'          and \emph{p} value.}
#'      \item{\code{est}}{A character string giving the descriptive estimates and confidence intervals if possible}
#'          % , either in units of the analyzed scale or as standardized effect size.
#'      \item{\code{full}}{A joint character string comprised of \code{est} and \code{stat}.}
#'    }
#'
#' @family apa_print
#' @examples
#' # Comparisions of central tendencies
#' t_stat <- t.test(extra ~ group, data = sleep)
#' apa_print(t_stat)
#' apa_print(t_stat, stat_name = "tee")
#'
#' wilcox_stat <- wilcox.test(extra ~ group, data = sleep)
#' apa_print(wilcox_stat)
#'
#' # Correlations
#' ## Data from Hollander & Wolfe (1973), p. 187f.
#' x <- c(44.4, 45.9, 41.9, 53.3, 44.7, 44.1, 50.7, 45.2, 60.1)
#' y <- c( 2.6,  3.1,  2.5,  5.0,  3.6,  4.0,  5.2,  2.8,  3.8)
#' cor_stat <- cor.test(x, y, method = "spearman")
#' apa_print(cor_stat)
#'
#' # Contingency tables
#' ## Data from Fleiss (1981), p. 139.
#' smokers  <- c(83, 90, 129, 70)
#' patients <- c(86, 93, 136, 82)
#' prop_stat <- prop.test(smokers, patients)
#' apa_print(prop_stat, n = sum(patients))
#' @export

apa_print.htest <- function(
  x
  , stat_name = NULL
  , n = NULL
  , ci = NULL
  , in_paren = FALSE
  , ...
) {
  validate(x, check_class = "htest")
  if(!is.null(stat_name)) validate(stat_name, check_class = "character", check_length = 1)
  if(!is.null(n)) validate(n, check_class = "numeric", check_integer = TRUE, check_range = c(0, Inf), check_length = 1)
  if(!is.null(ci)) validate(ci, check_class = "matrix", check_length = 2)
  validate(in_paren, check_class = "logical", check_length = 1)

  if(in_paren) {
    op <- "["; cp <- "]"
  } else {
    op <- "("; cp <- ")"
  }

  if(is.null(stat_name)) stat_name <- names(x$statistic)
  stat <- printnum(x$statistic)

  if(!is.null(x$sample.size)) n <- x$sample.size

  if(!is.null(x$parameter)) {
    # Statistic and degrees of freedom
    if(tolower(names(x$parameter)) == "df") {
      if(x$parameter %%1 == 0) printdigits <- 0 else printdigits = 2
      stat_name <- convert_stat_name(stat_name)
      if(stat_name == "\\Chi^2") {
        if(is.null(x$sample.size) & is.null(n)) stop("Please provide the sample size to report.") # Demand sample size information if it's a Chi^2 test
        stat_name <- paste0(stat_name, op, printnum(x$parameter[grep("df", names(x$parameter), ignore.case = TRUE)], digits = printdigits), ", n = ", n, cp)
      } else {
        stat_name <- paste0(stat_name, op, printnum(x$parameter[grep("df", names(x$parameter), ignore.case = TRUE)], digits = printdigits), cp)
      }
    }
  }

  # p-value
  p <- printp(x$p.value)
  if(!grepl("<|>", p)) eq <- "= " else eq <- ""

  apa_res <- list()
  apa_res$stat <- paste0("$", stat_name, " = ", stat, "$, $p ", eq, p, "$")

  # Estimate
  if(!is.null(names(x$estimate))) est_name <- convert_stat_name(names(x$estimate)) else est_name <- NULL
  est_gt1 <- TRUE

  if(is.null(est_name)) {
    est <- NULL
  } else if(est_name == "\\Delta M") {
    est <- printnum(diff(x$estimate))
  } else if(length(x$estimate) == 1) {
    if(names(x$estimate) %in% c("cor", "rho", "tau")) est_gt1 <- FALSE
    est <- printnum(x$estimate, gt1 = est_gt1)
  }

  if(!is.null(est)) {
    if(!grepl("<|>", est)) eq <- " = " else eq <- ""

    if(is.null(ci) && !is.null(x$conf.int)) { # Use CI in x
      apa_res$est <- paste0("$", est_name, eq, est, "$, ", make_confint(x$conf.int, gt1 = est_gt1))
    } else if(!is.null(ci)) { # Use supplied CI
      apa_res$est <- paste0("$", est_name, eq, est, "$, ", make_confint(ci, gt1 = est_gt1, margin = 2))
    } else if(is.null(ci) && is.null(x$conf.int)) { # No CI
      apa_res$est <- paste0("$", est_name, eq, est, "$")
    }

    apa_res$full <- paste(apa_res$est, apa_res$stat, sep = ", ")
  }

  apa_res
}
