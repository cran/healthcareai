#' Train models without tuning for performance
#'
#' @param d A data frame from \code{\link{prep_data}}. If you want to prepare
#' your data on your own, use \code{prep_data(..., no_prep = TRUE)}.
#' @param outcome Optional. Name of the column to predict. When omitted the
#'   outcome from \code{\link{prep_data}} is used; otherwise it must match the
#'   outcome provided to \code{\link{prep_data}}.
#' @param models Names of models to try. See \code{\link{get_supported_models}}
#'   for available models. Default is all available models.
#' @param metric Which metric should be used to assess model performance?
#'   Options for classification: "ROC" (default) (area under the receiver
#'   operating characteristic curve) or "PR" (area under the precision-recall
#'   curve). Options for regression: "RMSE" (default) (root-mean-squared error,
#'   default), "MAE" (mean-absolute error), or "Rsquared." Options for
#'   multiclass: "Accuracy" (default) or "Kappa" (accuracy, adjusted for class
#'   imbalance).
#' @param positive_class For classification only, which outcome level is the
#'   "yes" case, i.e. should be associated with high probabilities? Defaults to
#'   "Y" or "yes" if present, otherwise is the first level of the outcome
#'   variable (first alphabetically if the training data outcome was not already
#'   a factor).
#' @param n_folds How many folds to train the model on. Default = 5, minimum =
#'   2. Whie flash_models doesn't use cross validation to tune hyperparameters,
#'   it trains \code{n_folds} models to evaluate performance out of fold.
#' @param model_class "regression" or "classification". If not provided, this
#'   will be determined by the class of `outcome` with the determination
#'   displayed in a message.
#' @param model_name Quoted, name of the model. Defaults to the name of the
#' outcome variable.
#' @param allow_parallel Depreciated. Instead, control the number of cores though your
#' parallel back end (e.g. with \code{doMC}).
#'
#' @export
#' @seealso For setting up model training: \code{\link{prep_data}},
#'   \code{\link{supported_models}}, \code{\link{hyperparameters}}
#'
#'   For evaluating models: \code{\link{plot.model_list}},
#'   \code{\link{evaluate.model_list}}
#'
#'   For making predictions: \code{\link{predict.model_list}}
#'
#'   For optimizing performance: \code{\link{tune_models}}
#'
#'   To prepare data and tune models in a single step:
#'   \code{\link{machine_learn}}
#'
#' @return A model_list object. You can call \code{plot}, \code{summary},
#'   \code{evaluate}, or \code{predict} on a model_list.
#' @details This function has two major differences from
#'   \code{\link{tune_models}}: 1. It uses fixed default hyperparameter values
#'   to train models instead of using cross-validation to optimize
#'   hyperparameter values for predictive performance, and, as a result, 2. It
#'   is much faster.
#'
#'   If you want to train a model at a single set of non-default hyperparameter
#'   values use \code{\link{tune_models}} and pass a single-row data frame to
#'   the hyperparameters arguemet.
#'
#' @examples
#' \donttest{
#' # Prepare data
#' prepped_data <- prep_data(pima_diabetes, patient_id, outcome = diabetes)
#'
#' # Get models quickly at default hyperparameter values
#' flash_models(prepped_data)
#'
#' # Speed comparison of no tuning with flash_models vs. tuning with tune_models:
#' # ~15 seconds:
#' system.time(
#'   tune_models(prepped_data, diabetes)
#' )
#' # ~3 seconds:
#' system.time(
#'   flash_models(prepped_data, diabetes)
#' )
#' }
flash_models <- function(d,
                         outcome,
                         models,
                         metric,
                         positive_class,
                         n_folds = 5,
                         model_class,
                         model_name = NULL,
                         allow_parallel = FALSE) {

  model_args <- setup_training(d, rlang::enquo(outcome), model_class, models,
                               metric, positive_class, n_folds)
  metric <- model_args$metric
  # Pull each item out of "model_args" list and assign in this environment
  for (arg in names(model_args))
    assign(arg, model_args[[arg]])

  train_control <- setup_train_control(model_class, metric, n_folds)
  hyperparameters <-
    get_hyperparameter_defaults(models = models, n = nrow(d), k = ncol(d) - 1,
                                model_class = model_class)
  if (metric == "PR")
    metric <- "AUC"

  # Rough check for training that will take a while, message if so
  check_training_time(ddim = dim(d), n_folds = n_folds,
                      hpdim = purrr::map_int(hyperparameters, nrow)) %>%
    message()

  train_list <- train_models(d, outcome, models, metric, train_control,
                             hyperparameters, tuned = FALSE,
                             allow_parallel = allow_parallel)
  train_list <- as.model_list(listed_models = train_list,
                              tuned = FALSE,
                              target = rlang::quo_name(outcome),
                              model_class = model_class,
                              recipe = recipe,
                              positive_class = attr(train_list, "positive_class"),
                              model_name = model_name,
                              best_levels = best_levels,
                              original_data_str = original_data_str,
                              versions = attr(train_list, "versions")) %>%
    structure(timestamp = Sys.time())
  return(train_list)
}
