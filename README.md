# Project notes

When using a data loader data gets called by an index, this index can be a vector of multiple locations (a batch).

The torch tensor will generally have the shape:

{1, 300, 4}

for a batch size of one on a matrix of 300 rows and 4 columns.

When fitting the model the routine tries to concat all the data. However, torch tensors can only be concatted with varying dimensions along position 1.

This means that if the size of the tensors is not the same across batches (i.e. varying columns), this will fail.

```r
output <- predict(fit, dataloader)
```

will not return stuff

You need to use the data loader iterator to step through all the data manually and gather the results this way.

ISSUE:

It is unclear if the same issue plays out when running the optimization. Although no errors are returned they might be hidden. Tests on the LSTM GPP model returns worse model results and this might be the reason.

NOTE:

The LSTM structure for GPP prediction isn't ideal for phenology prediction due to the weak correlation between GCC and continuous environmental factors. This is more threshold behaviour not a physical / delayed response.
