# Feedback on startup
message("Running the model on the test data...")

# set both the R seed
# and the torch seed (both function independently)
set.seed(1)
torch::torch_manual_seed(42)
epochs <- 10 # for testing purposes, set to 150 for full run

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

sites <- unique(df$id)
test_sites <- sites[!(sites %in% site_id)]

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
    !(id %in% site_id),
    #id == "bbc2 DB"
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
  shuffle = FALSE
)

#---- run the model on the test data ----

# # save model for this iteration
# # i.e. site left out
fitted <- luz_load("data/global_model.pt")

train_dl <- train_dl |>
  dataloader_make_iter()

i <- 1

while( i < length(train_dl)) {
  i <- i + 1

  # subset iterator
  subset <- train_dl |>
    dataloader_next()

  # run the model on the test data
  pred <- predict(fitted, subset)
  pred <- (as.numeric(torch_tensor(pred, device = "cpu")) +
              train_center$smooth_gcc_90_mean) *
    train_center$smooth_gcc_90_sd

  plot(pred)
}


# # save as a compressed RDS
# saveRDS(
#   leave_site_out_output,
#   "data/leave_site_out_output.rds",
#   compress = "xz"
# )
