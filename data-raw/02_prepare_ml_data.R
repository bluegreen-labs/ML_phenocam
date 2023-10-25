# load required libraries
library(dplyr)
library(tidyr)
library(hwsdr)

# prepare the data for machine learning
df <- readRDS("data-raw/raw_time_series_output.rds")

# only retain required data
df <- df |>
  rename(
    "daymet_daylength" = "dayl..s.",
    "daymet_precip" = "prcp..mm.day.",
    "daymet_radiation" = "srad..W.m.2.",
    "daymet_tmax"= "tmax..deg.c.",
    "daymet_tmin"= "tmin..deg.c.",
    "daymet_vp" = "vp..Pa."
  )

df <- df |>
  select(
    site,
    lat,
    lon,
    elev,
    veg_type,
    roi_id,
    smooth_gcc_90,
    starts_with("daymet")
  )

# get soil characteristics

# set the ws_path variable using a FULL path name
# will download required data in set path if missing
path <- ws_download(
  ws_path = "data-raw/hwsd/",
  verbose = TRUE
)

hwsd_df <- df |>
  select(site, lat, lon) |>
  unique() |>
  group_by(site) |>
  do({
    values <- ws_subset(
      site = "HWSD_V2",
      location = c(.data$lon, .data$lat),
      param = c("BULK","SAND","SILT","CLAY","AWC"),
      layer = "D1",
      version = "2.0", # set correct HWSD version
      ws_path = path
    ) |>
      tidyr::pivot_wider(
        values_from = value,
        names_from = parameter
      ) |>
      select(
        -longitude,
        -latitude,
        -site
      )
  }) |>
  rename(
    "hwsd_bulk" = "BULK",
    "hwsd_sand" = "SAND",
    "hwsd_silt" = "SILT",
    "hwsd_clay" = "CLAY",
    "hwsd_awc" = "AWC"
  ) |>
  ungroup()

# merge soil data with climate and time series
df <- left_join(df, hwsd_df)

# save ML data frame
saveRDS(df, "data/ml_time_series_data.rds", compress = "xz")