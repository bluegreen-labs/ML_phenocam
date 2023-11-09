#' Normalize PhenoCam time series
#'
#' Normalize PhenoCam data between 0-1 to to standardize
#' further processing, independent of the relative amplitude
#' of the time series (works on vectors not data frames).
#' For internal use only.
#'
#' @param df a time series vector
#' @param min percentile for calculating the lower normalization bound
#' @param max percentile for calculating the upper normalization bound
#' @return A normalized PhenoCam time series.
#' @export
#' @examples
#'
#' # Internal function only, should not be used stand-alone.
#' # As such no documentation is provided.

normalize <- function(df, min = 0.25, max = 0.95){

  # find range
  max_val <- quantile(df, max)
  min_val <- quantile(df, min)

  # normalize
  df  = (df - min_val)/(max_val - min_val)
  df[df < 0] <- 0

  # return data
  return(df)
}

#' Fixed baseline PhenoCam time series
#'
#' Provides a fixed baseline for all time series, making the assumption
#' that the amplitude of the signal contains some physical meaning and
#' the standardization of the network reduces site by site variability
#' enough to make this information useful
#'
#' @param df a time series vector
#' @param percentile percentile value to interprete
#' @return A normalized PhenoCam time series.
#' @export
#' @examples
#'
#' # Internal function only, should not be used stand-alone.
#' # As such no documentation is provided.

baseline <- function(df, percentile = 0.25){

  # find range
  min_val <- quantile(df, percentile)

  # normalize
  df  = df - min_val
  df[df < 0] <- 0

  # return data
  return(df)
}
