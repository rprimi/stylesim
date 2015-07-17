#' Simulate Data From a Multidimensional Rasch Model
#'
#' This function allows to simulate data from a multidimensional Rasch model, in
#' which one (or more) latent variables represent response styles such as
#' extreme response style or acquiescence.
#'
#' @param n Desired number of observations / persons
#' @param items Desired number of items / stimuli. If \code{ndimc} > 1, this
#'   specifies the number of items per dimension.
#' @param categ Desired number of categories per item
#' @param ndimc Desired number of content-related latent variables (irrespective
#'   of number of style-related latent variables)
#' @param style Parameter to specify which response style(s) influence the data,
#'   can be either numeric or character. Users may choose one or more among
#'   \code{"ERS1"} (e.g., 1 / 0 / 0 / 0 / 1), \code{"ERS2"} (e.g., 2 / 1 /
#'   0 / 1 / 2), \code{"ARS"} (e.g., 0 / 0 / 0 / 1 / 1), \code{"ADRS"}
#'   (e.g, -1 / -1 / 0 / 1 / 1), and \code{"MRS"} (e.g., 0 / 0 / 1 / 0 /
#'   0). Alternatively, a user-specified vector of weights can be employed. Can
#'   also be \code{NULL} indicating complete abscence of response styles.
#' @param irtmodel A character string indicating which model to use. Currently
#'   available is \code{"RSM"} (i.e., rating scale model).
#' @param reversed Indicates the number of reverse-coded items. Can be either a
#'   ratio between 0 and 1 indicating the ratio of reverse-coded items or an
#'   integer between 0 and \code{items}) indicating the number of reverse-coded
#'   items.
#' @param var.s A vector indicating the variance of the style-related latent
#'   variables
#' @param cor.cc An optional vector indicating the correlation between the
#'   content-related variables (if \code{ndimc} > 1). If \code{ndimc} > 2,
#'   \code{cor.cc} is recycled if it is not of length \code{ndimc*(ndimc-1) * 1
#'   / 2}.
#' @param my.seed Optional argument to specify a seed for the probabilistic
#'   draws of the responses given theta and the thresholds.
#' @param pop.thres Logical. If \code{TRUE}, the thresholds of the RSM are set
#'   to their expected value.
#' @param my.theta Optional argument to employ a pre-specified vector of person parameters theta
#' @param my.thres Optional argument to employ a pre-specified vector of item parameters.
#' @return Returns a list containing the data and basically a summary of the
#'   input specifications with elements \describe{
#'
#'   \item{dat}{an array containing the data / responses of format \code{n} x
#'   \code{items} x \code{ndimc}}
#'
#'   \item{theta}{a matrix containing the true person parameters of format
#'   \code{n} x \code{(ndimc + length(style))}. For example, if \code{ndimc = 1},
#'   and \code{style = c("ERS1", "ARS")}, then the second column corresponds to
#'   "ERS1" and the third column to "ARS".}
#'
#'   \item{item.parameters}{a vector containing the item parameters
#'
#'   \item{n}{number of observations}
#'
#'   \item{items.per.dimension}{number of items per dimension}
#'
#'   \item{reverse.coded.items}{number of reverse-coded items per dimension}
#'
#'   \item{categories}{number of categories}
#'
#'   \item{irtmodel}{type of IRT model}
#'
#'   \item{dims.content}{number of content-related dimensions}
#'
#'   \item{var.style}{optional. Variance of the style-related latent
#'   variable(s).}
#'
#'   \item{c.c.cor}{optional. Correlation of the content-related latent
#'   variables.}
#'
#'   \item{response.style}{\describe{ \item{the specified response style(s)}{}
#'   \item{the implied coding scheme}{}}}
#'
#'   }
#' @export
# @importFrom magic adiag
# @importFrom MASS mvrnorm
# @importFrom truncnorm rtruncnorm
# @importFrom gtools odd
sim_style_data <- function(n = 200, items = 10, categ = 5, ndimc = 1,
                           style = NULL, irtmodel = "RSM", reversed = 1/3,
                           var.s, mu.s = 0, cor.cc, my.seed, pop.thres = FALSE,
                           my.theta, my.thres, emp = FALSE, sig) {

    # library("magic"); library("MASS"); library("truncnorm")

    if (!is.null(style) & missing(var.s) & missing(my.theta)) {
        warning("### Variance of the response style dimension(s) is set to 1, check
  ### that this is intended and possibly specify 'var.s'.")}
    if (is.null(style) & !missing(var.s)) {
        stop("### Not possible to specify the variance of the style dimension
  ### 'var.s', if argument 'style' is not specified")
    }

    # ARGUMENT WRANGLING -------------------------------------------------------
    items.tot <- items * ndimc
    revs <- ifelse(reversed >= 1, reversed, trunc(items * reversed))
    reg <- items - revs
    #   revs.tot <- revs * ndimc
    #   reg.tot <- reg * ndimc
    ndims <- ifelse(is.character(style), length(style), length(style)/categ)
    ndim <- ndimc + ndims
    if (revs >= items) stop("### Function needs at least one regular item.")

    # THETA --------------------------------------------------------------------
    # [DIM x N] MATRIX
    if (missing(sig)) {
        sig <- matrix(0, nrow = ndim, ncol = ndim)
        diag(sig) <- 1
        if (!missing(var.s)) {
            diag(sig)[(ndimc + 1):ndim] <- var.s
        }

        # the next 11 lines adapt the Var-Cov-Matrix if c and c are correlated
        if (!missing(cor.cc)) {
            if(length(cor.cc) == 1) {
                cor.cc <- rep(cor.cc, (ndimc* (ndimc - 1) / 2))
            }
            if (length(cor.cc) != (ndimc* (ndimc - 1) / 2)) {
                stop("### Incorrect specification of the number of elements for the
  ### var-cov-matrix of the content-related variables")
            }
            sig[1:ndimc, 1:ndimc][upper.tri(sig[1:ndimc, 1:ndimc])] <- cor.cc
            sig[1:ndimc, 1:ndimc][lower.tri(sig[1:ndimc, 1:ndimc])] <- cor.cc
        }
    } else {
        if (!isSymmetric(sig)) stop("### The matrix 'sig' is not symmetric")
        if (ndim != ncol(sig)) stop("### Matrix 'sig' is of wrong dimension")
    }


    if (missing(mu.s)) mu.s <- 0
    if (length(mu.s) != ndims) {
        mu.s <- rep(mu.s, ndims)
    }
    mu.vec <- c(rep(0, ndimc), mu.s)
    theta <- t(MASS::mvrnorm(n = n, mu = mu.vec, Sigma = sig, empirical = emp))
    if (is.null(style)) {
        rownames(theta) <- paste("content", 1:ndimc, sep = "")
    } else {
        rownames(theta) <- c(paste("content", 1:ndimc, sep = ""),
                             ifelse(is.character(style), style, paste("style", 1:ndims, sep = "")))
    }


    if (!missing(my.theta)) {
        if (is.vector(my.theta)) {
            my.theta <- matrix(my.theta, ncol = 1)
        }
        if (ncol(my.theta) > ndim) {
            stop("### Argument 'my.theta' has too many columns.")
        } else {
            theta[1:ncol(my.theta), ] <- t(my.theta)
        }
        if (ncol(my.theta) != ndim) {
            warning("### The variance of the dimensions that were not part of
  ### 'my.theta' are set to 1, check that this was intended.")
        }
    }

    # THRESHOLDS ---------------------------------------------------------------
    # [ITEMS*(CATEG-1) x N] MATRIX
    # For identification of the rating scale model, see comment below.
    if (!missing(my.thres)) {
        if (length(my.thres) != categ + items.tot - 1) {
            stop("### Argument 'my.thres' has wrong length.")
        }
        if (revs > 0) warning(paste(
            "### The last", revs, "item(s) are reverse-coded, check that this is
  ### intended and possibly alter the order of 'my.thres'."))
        thres.rsm <- my.thres[(items.tot + 1):length(my.thres)]
        loc <- my.thres[1:items.tot]
        if (!is.unsorted(loc, strictly = T) & revs > 0) {
            stop("### You are not allowed to reverse-code items if item locations are
  ### sorted. Please shuffle order of item locations.")
        }

    } else {
        if (irtmodel == "RSM") {

            t.min <- -2.5
            t.max <- 2.5

            if (pop.thres == TRUE) {
                x1 <- seq(t.min, t.max, length = (categ + 1))
                thres.rsm <- x1[2:(length(x1) - 1)]
            } else {
                repeat {
                    thres.rsm <- sort(runif(categ - 1, min = t.min, max = t.max))
                    thres.rsm <- thres.rsm - mean(thres.rsm)
                    if (max(abs(thres.rsm)) <= 2.5) break
                }
            }

            loc <- truncnorm::rtruncnorm(items.tot, a = -1.5, b = 1.5, mean = 0, sd = sqrt(1))

            #       loc <- numeric()
            #       for (i in 1:ndimc) {
            #         x2 <- seq(-1.5, 1.5, length = (reg + 2))
            #         loc <- c(loc, x2[2:(length(x2) - 1)])
            #         if (revs > 0) {
            #           x3 <- seq(-1.5, 1.5, length = (revs + 2))
            #           loc <- c(loc, x3[2:(length(x3) - 1)])
            #         }
            #       }
            #       loc <- rep(loc, each = categ - 1)

        } else {
            stop("### Item parameters are currently defined only for the rating scale
  ### model. Please modify argument 'irtmodel'.")
        }
    }

    thres <- c(loc, thres.rsm)

    thres <- matrix(thres, nrow = length(thres), ncol = n)

    # B-MATRIX -----------------------------------------------------------------
    # [ITEMS*CATEG x DIM] MATRIX
    B <- matrix(rep(0:(categ - 1), items), ncol = 1)
    #   B <- matrix(c(rep(0:(categ - 1), reg), rep((categ - 1):0, revs)))
    B <- do.call(magic::adiag, rep(list(B), ndimc))

    if (is.numeric(style)) {
        if (length(style) != categ) stop("### Incorrect number of weights specified")
        B <- cbind(B,
                   matrix(c(rep(style, reg), rep(rev(style), revs)),
                          ncol = 1, nrow = items.tot * categ))
    } else {
        for (i in seq(along = style)) {
            if ("ERS1" %in% style[i]) {
                ERS <- rep(0, categ)
                ERS[1] <- ifelse(categ > 2, 1, 0)
                ERS[length(ERS)] <- ifelse(categ > 2, 1, 0)
                B <- cbind(B, matrix(ERS, ncol = 1, nrow = items.tot * categ))
            }
            if ("ERS2" %in% style[i]) {
                # library("gtools")
                #         ERS <- c((ceiling(categ / 2) - 1):0,
                #                  ifelse(gtools::odd(categ), 1, 0):(ceiling(categ / 2) - 1))
                x1 <- categ * 3
                ERS <- c((trunc(x1 / 2) - 1):1, rep(0, ifelse(gtools::odd(x1), 3, 2)),
                         1:(trunc(x1 / 2) -1)); rm(x1)
                ERS <- head(ERS, n = -(length(ERS) - categ) / 2)
                (ERS <- tail(ERS, categ))
                if (categ == 3) ERS <- c(1, 0, 1)
                B <- cbind(B, matrix(ERS, ncol = 1, nrow = items.tot * categ))
            }
            if ("ARS" %in% style[i]) {
                # e.g., 0 0 0 0 1 1 1
                ARS <- rep(1, categ)
                ARS[1:ceiling(categ / 2)] <- 0
                #         B <- cbind(B, matrix(ARS, ncol = 1, nrow = items.tot * categ))
                B <- cbind(B, matrix(rep(c(rep(ARS, reg), rep(rev(ARS), revs)),
                                         ndimc), ncol = 1))
            }
            if ("ADRS" %in% style[i]) {
                # e.g., -1 -1 -1  0  1  1  1
                ADRS <- rep(0, categ)
                ADRS[1:trunc(categ / 2)] <- - 1
                ADRS[(ceiling(categ / 2) + 1):categ] <- 1
                B <- cbind(B, matrix(ADRS, ncol = 1, nrow = items.tot * categ))
            }
            if ("MRS" %in% style[i]) {
                # library("gtools")
                if (gtools::odd(categ)) {
                    MRS <- rep(0, categ)
                    MRS[ceiling(categ / 2)] <- 1
                    B <- cbind(B, matrix(MRS, ncol = 1, nrow = items.tot * categ))
                }
            }
        }
    }

    #   B <- B - matrix(apply(B[1:categ, , drop = F], 2, mean),
    #                   nrow = nrow(B), ncol = ncol(B), byrow = T)
    #   B <- B / matrix(sqrt(diag(t(B[1:categ, ]) %*% B[1:categ, ])),
    #                   nrow = nrow(B), ncol = ncol(B), byrow = T)

    # A-MATRIX -----------------------------------------------------------------
    # [ITEMS*CATEG x ITEMS*(CATEG-1)] MATRIX

    # Note that no identification constraint is placed on the A-matrix!! This is
    # especially important with respect to the thresholds in the rating scale
    # model (RSM). All RSM-thresholds are sampled (above) from the same
    # distribution to ensure that they have the same distributional properties.
    # The alternative way of, for example, fixing the last threshold to minus
    # the sum of the others leads to the problem that the last threshold no
    # longer belongs to the same distributional family than the others.
    A <- diag(1, categ - 1)
    A[lower.tri(A)] <- 1
    A <- rbind(0, A)
    A <- do.call(rbind, rep(list(A), items.tot))
    A2 <- do.call(magic::adiag, rep(list(t(t(0:(categ - 1)))), items.tot))
    A <- cbind(A2, A)


    # IRT MODEL -> DATA --------------------------------------------------------
    num <- exp(B %*% theta - A %*% thres)
    num <- array(num, dim = c(categ, items.tot, n))
    den <- array(rep(colSums(num), each = categ), dim = c(categ, items.tot, n))
    p <- num / den

    # the loop is about 6.5 ms slower (using default arguments), but makes it
    # possible to specify seeds
    if (!missing(my.seed)) {
        dat <- matrix(nrow = n, ncol = items.tot)
        for (i in 1:items.tot) {
            for (j in 1:n) {
                set.seed(my.seed + .5*(i+j)*(i+j+1)+j)
                dat[j, i] <- as.integer(findInterval(runif(1),
                                                     cumsum(p[, i, j])))
            }
        }
    } else {
        dat <- t(apply(p, c(2, 3), function(i) {
            as.integer(findInterval(runif(1), cumsum(i)))
        }))
    }

    dat <- array(dat, dim = c(n, items.tot / ndimc, ndimc))

    # RETURN RESULTS -----------------------------------------------------------
    if(irtmodel == "RSM") {
        item.par = c(loc, thres.rsm)
        names(item.par) <- c(paste("item", 1:items.tot, sep = ""),
                             paste("categ", 1:(categ - 1), sep = ""))
    }

    res <- list(dat = dat, theta = t(theta), item.parameters = item.par, n = n,
                items.per.dimension = items, reverse.coded.items = revs,
                categories = categ, irtmodel = irtmodel, dims.content = ndimc)
    if (ndimc > 1) {
        res <- c(res, c.c.cor = list(sig)
                 #                list(sig[1:ndimc, 1:ndimc][upper.tri(sig[1:ndimc, 1:ndimc])])
        )
    }
    if (length(style) > 0) {
        res <- c(res, response.style =
                     list(list(style = style,
                               coding = B[1:categ, (ndimc+1):ncol(B), drop = FALSE],
                               mu.style = mu.s,
                               var.style = ifelse(rep(missing(var.s), ndims),
                                                  1, var.s))))
    }
    return(res)
}