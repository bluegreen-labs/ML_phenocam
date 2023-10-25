# load required libraries
library(phenocamr)
library(dplyr)

# list all sites
sites <- phenocamr::list_sites()

# only use Type I sites, and natural vegetation types
sites <- sites |>
  filter(
    site_type == "I"
  ) |>
  select(
    site
  )

# list all rois for the selected sites
rois <- phenocamr::list_rois() |>
  filter(
    sites %in% !!sites,
    missing_data_pct < 10,
    site_years > 2,
    veg_type %in% c("EN","DB","GR","SH"),
    roi_id_number == 1000,
    lon < -50
  ) |>
  select(
    site,
    lat,
    lon,
    veg_type,
    roi_id_number,
    site_years
  )

# combine all data in a consistent data frame
files <- list.files("data-raw/phenocam/","*3day.csv", full.names = TRUE)

# global output compilation routine
output <- lapply(files, function(file){

  # read data file
  # NOTE: include a new option to return
  # a tidy format in phenocamr
  df <- phenocamr::read_phenocam(file)

  # compile initital output
  output <- df$data
  output$site <- df$site
  output$veg_type <- df$veg_type
  output$roi_id <- df$roi_id
  output$elev <- df$elev
  output$lat <- df$lat
  output$lon <- df$lon
  return(output)
})

output <- dplyr::bind_rows(output)
saveRDS(output, "data-raw/raw_time_series_output.rds", compress = "xz")

# If consistent this should be replaced by, although
# the current data layout doesn't allow tidy data processing
# output <- vroom::vroom(files, skip = 24, delim = ",")
