# Feedback on startup
message("Running the model on the test data...")

# set both the R seed
# and the torch seed (both function independently)
set.seed(1)
torch::torch_manual_seed(42)
fraction <- 0.8

# required libraries
library(torch)
library(luz)
library(dplyr)
source("R/gcc_dataset.R")

# automatically use the GPU if available
device <- torch::torch_device(
  if (torch::cuda_is_available()) "cuda" else "cpu"
)

# read in data, only retain relevant features
df <- readRDS("data/ml_time_series_data_gcc_baseline.rds") |>
  dplyr::mutate(
    id = paste(site, veg_type)
  ) |>
  as.data.frame()

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
    fraction,
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

# grab test_site names
train_sites <- unique(train$site)

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
    starts_with("daymet")
  ) |>
  ungroup()

# format torch data loader
# for training data
train_ds <- train |>
  gcc_dataset(
    train_center
  )

# grab test_site names
train_sites <- unique(train$site)

# format torch data loader
# for test data
test <- df |>
  dplyr::filter(
    !(id %in% site_id)
  )

# grab test_site names
test_sites <- unique(test$site)

test_ds <- test |>
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
  shuffle = FALSE
)

test_dl <- dataloader(
  test_ds,
  batch_size = 1,
  shuffle = FALSE
)

#---- run the model on the test data ----

# # save model for this iteration
# # i.e. site left out
fitted <- luz_load("data/global_model_gcc.pt")

test_dl <- test_dl |>
  dataloader_make_iter()

i <- 0

global_model_validation <- lapply(1:length(test_dl), function(i){

  # subset iterator
  subset <- test_dl |>
    dataloader_next()

  # run model
  pred <- predict(fitted, subset)

  # convert to cpu memory
  pred <- try(as.numeric(torch_tensor(pred, device = "cpu")))

  i <<- i + 1

  df_subset <- test |>
    filter(
      site == test_sites[i]
    )

  df_subset$gcc_pred <- pred

  df_subset <- df_subset |>
    mutate(
      date = as.Date(date)
    )

  return(df_subset)

})

# bind all rows
global_model_validation <- bind_rows(global_model_validation)

# save as a compressed RDS
saveRDS(
  global_model_validation,
  "data/global_model_gcc_baseline.rds",
  compress = "xz"
)
