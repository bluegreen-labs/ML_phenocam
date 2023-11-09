# load required libraries and data
library(dplyr)
library(tidyr)
library(hwsdr)
source("R/normalize.R")

# site meta data
site_meta_data <- phenocamr::list_sites() |>
  select(
    site,
    flux_sitenames,
    primary_veg_type
  )

# prepare the data for machine learning
df <- readRDS("data-raw/raw_time_series_output.rds")

#---- data wrangling bit ----

# only retain required data and kick out spruce sites
df <- df |>
  rename(
    "daymet_daylength" = "dayl..s.",
    "daymet_precip" = "prcp..mm.day.",
    "daymet_radiation" = "srad..W.m.2.",
    "daymet_tmax"= "tmax..deg.c.",
    "daymet_tmin"= "tmin..deg.c.",
    "daymet_vp" = "vp..Pa."
  ) |>
  filter(
    !grepl("spruce", site)
  )

df <- df |>
  dplyr::select(
    site,
    lat,
    lon,
    date,
    elev,
    veg_type,
    roi_id,
    smooth_gcc_90,
    starts_with("daymet")
  )

df_norm <- df |>
  group_by(site) |>
  dplyr::mutate(
    smooth_gcc_90 = normalize(smooth_gcc_90) * 100
  ) |>
  ungroup()

df_baseline <- df |>
  group_by(site) |>
  dplyr::mutate(
    smooth_gcc_90 = baseline(smooth_gcc_90) * 100
  ) |>
  ungroup()

# save normalized GCC dataset
saveRDS(df_norm, "data/ml_time_series_data_gcc.rds", compress = "xz")

# save baseline GCC dataset
saveRDS(df_baseline, "data/ml_time_series_data_gcc_baseline.rds", compress = "xz")

break

# get soil characteristics

# set the ws_path variable using a FULL path name
# will download required data in set path if missing
path <- ws_download(
  ws_path = "data-raw/hwsd/",
  verbose = TRUE
)

hwsd_df <- df_norm |>
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
df <- left_join(df_norm, hwsd_df)

# merge meta-data
df <- left_join(df, site_meta_data) |>
  filter(
    flux_sitenames != "",
    !is.na(flux_sitenames),
  ) |>
  mutate(
    date = as.Date(date)
  )

# fluxes
fluxes <- readRDS("data/rsofun_driver_data_clean.rds") |>
  select(sitename, forcing) |>
  unnest() |>
  select(
    sitename,
    date,
    gpp
  ) |>
  rename(
    "flux_sitenames" = "sitename"
  )

# merge with fluxes
df <- inner_join(df, fluxes)

# drop non primary veg types and flux site names
df <- df |>
  filter(
    veg_type == primary_veg_type
  ) |>
  select(
    -flux_sitenames,
    -primary_veg_type
  )

# save ML data frame
saveRDS(df, "data/ml_time_series_data_fluxes.rds", compress = "xz")
