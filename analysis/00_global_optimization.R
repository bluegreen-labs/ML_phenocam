# Feedback on startup
message("Global optimization, stratified across vegetation types...")

# set both the R seed
# and the torch seed (both function independently)
set.seed(1)
torch::torch_manual_seed(42)
epochs <- 100 # for testing purposes, set to 150 for full run

# required libraries
library(torch)
library(luz)
library(dplyr)
source("R/rnn_model.R")
source("R/gcc_dataset.R")

# automatically use the GPU if available
device <- torch::torch_device(
  if (torch::cuda_is_available()) "cuda" else "cpu"
  )

# read in data, only retain relevant features
df <- readRDS("data/ml_time_series_data.rds") |>
  dplyr::mutate(
    id = paste(site, veg_type)
  ) |>
  filter(
    veg_type == "DB"
  )

#--- stratification of data ----

# global optimization, with 0.2,0.2,0.6
# split of data in testing, validation, training
# data will not be weighted according to
# the number of site years only across
# the strata vegetation type

split <-  df |>
  dplyr::select(veg_type, id) |>
  unique() |>
  rsample::initial_split(
  0.8,
  strata = "veg_type"
  )

site_id <- split$data[split$in_id, "id"]

# split routine in training and testing,
# training will be further divided in
# training and validation

# split out leave one site out
# training and testing data
train <- df |>
  dplyr::filter(
    id %in% site_id
  )

# calculated mean / sd to center
# the data
train_center <- train |>
  summarise(
    across(
      where(is.numeric),
      list(mean = mean, sd = sd)
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
  gcc_dataset(
    train_center
  )

# format torch data loader
# for test data
test_ds <- df |>
  dplyr::filter(
    !(id %in% site_id)
  ) |>
  gcc_dataset(
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
  shuffle = TRUE
)

#---- model fitting -----

# fit the model by defining
# a setup, setting parameters
# and then initiating the fitting
fitted <- rnn_model |>
  setup(
    loss = nn_mse_loss(),
    optimizer = optim_adam,
    metrics = list(luz_metric_mae())
  ) |>
  set_hparams(
    input_size = ncol(train_ds[1]$x),
    hidden_size = 256,
    output_size = 1
  ) |>
  fit(
    train_dl,
    epochs = epochs
  )

# save model for this iteration
# i.e. site left out
luz_save(
  fitted,
  file.path(
    here::here("data/leave_site_out_weights/",
               "global_model.pt")
  )
)
