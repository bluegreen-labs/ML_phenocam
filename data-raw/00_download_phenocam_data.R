# Download all phenology data
# Download the latest phenocam
# data and reprocess constrained
# to 2022

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
    veg_type,
    roi_id_number,
    site_years
  )

# print the distribution of site years across
# vegetation types
message("The sites per veg class:")
rois |>
  group_by(veg_type) |>
  summarize(
    sum(site_years)
  ) |>
  print()

# download and process all data
# loop over all rois and put data
# in data-raw for now
if(!dir.exists("data-raw/phenocam/")) dir.create("data-raw/phenocam/")

apply(rois, 1, function(roi){
  phenocamr::download_phenocam(
    site = sprintf("%s$",roi['site']),
    veg_type = roi['veg_type'],
    roi_id = 1000,
    daymet = TRUE,
    phenophase = TRUE,
    trim = 2022,
    out_dir = "data-raw/phenocam/"
    )
})
