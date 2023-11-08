# Feedback on startup
message("Global optimization, stratified across vegetation types...")

# set both the R seed
# and the torch seed (both function independently)
set.seed(1)
torch::torch_manual_seed(42)
epochs <- 25

# required libraries
library(torch)
library(luz)
library(dplyr)
library(ggplot2)
source("R/rnn_model.R")
source("R/fluxes_dataset.R")

# automatically use the GPU if available
device <- torch::torch_device(
  if (torch::cuda_is_available()) "cuda" else "cpu"
)

# read in data, only retain relevant features
df <- readRDS("data/ml_time_series_data_fluxes.rds") |>
  dplyr::mutate(
    id = paste(site, veg_type)
  ) |>
  as.data.frame()

#--- stratification of data ----

# leave site out stratification
site_id <- unique(df$id)

#---- model fitting -----

# loop over all sites (drop the one mentioned)
# use a lapply rather than a for loop as lapply
# does not create global variables which might
# get recycled if not carefully purged
leave_site_out_output <- lapply(site_id, function(site){

  message(sprintf("Running %s ...", site))

  # split routine in training and testing,
  # training will be further divided in
  # training and validation

  # split out leave one site out
  # training and testing data
  train <- df |>
    dplyr::filter(
      id != !!site
    )

  test <- df |>
    dplyr::filter(
      id == !!site
    )

  # calculated mean / sd to center
  # the data
  train_center <- train |>
    summarise(
      across(
        where(is.numeric),
        list(
          mean = mean,
          sd = sd
        )
      )
    ) |>
    select(
      starts_with("smooth"),
      starts_with("daymet")
    ) |>
    ungroup()

  # format torch data loader
  # for training data
  train_ds <- train |>
    fluxes_dataset(
      train_center
    )

  test_ds <- test |>
    fluxes_dataset(
      train_center
    )

  #---- data loaders -----

  # run data loaders, batch
  # size is limited to 1 as
  # the dimensions of the input
  # should be equal to take advantage
  # of batch processing (probably due
  # to underlying matrix optimization)
  train_dl <- dataloader(
    train_ds,
    batch_size = 1,
    shuffle = TRUE
  )

  test_dl <- dataloader(
    test_ds,
    batch_size = 1,
    shuffle = FALSE
  )

  fitted <- try(luz_load(
    file.path(
      here::here("data/leave_site_out_weights_lstm/",
                 paste0(site, ".pt"))
    )
  ))

  if(inherits(fitted, 'try-error')){
    return(NULL)
  }

  # run the model on the test data
  pred <- as.numeric(torch_tensor(predict(fitted, test_dl), device = "cpu"))

  # add date for easy integration in
  # original data
  df <- df |>
    dplyr::filter(
      id == !!site
    )

  date <- df |>
    dplyr::select(
      date
    )

  gpp <- df |>
    dplyr::select(
      gpp
    )

  # return comparisons
  return(data.frame(
    sitename = site,
    date = date,
    gpp = gpp,
    gpp_pred = pred
  ))
})

# compile everything in a tidy dataframe
leave_site_out_output <- bind_rows(leave_site_out_output)

# save as a compressed RDS
saveRDS(
  leave_site_out_output,
  "data/leave_site_out_output_fluxes.rds",
  compress = "xz"
)
