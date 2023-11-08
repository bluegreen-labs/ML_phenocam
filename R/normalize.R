#' Normalize PhenoCam time series
#'
#' Normalize PhenoCam data between 0-1 to to standardize
#' further processing, independent of the relative amplitude
#' of the time series (works on vectors not data frames).
#' For internal use only.
#'
#' @param df a PhenoCam data frame
#' @param percentile percentile value to interprete
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
