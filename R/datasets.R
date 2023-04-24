#' Rules data
#'
#' A dataset containing rules and their descriptions, datasets, valid examples, severity, and rules.
#'
#' @format A data frame with 6 columns:
#' \describe{
#'   \item{name}{Name of the rule (e.g., "MethodologyID_valid")}
#'   \item{description}{Description of the rule (e.g., "URL address is valid and can be found on the internet.")}
#'   \item{dataset}{Dataset associated with the rule (e.g., "methodology")}
#'   \item{valid_example}{A valid example of the rule (e.g., "https://www.waterboards.ca.gov/drinking_water/certlic/drinkingwater/documents/microplastics/mcrplsts_plcy_drft.pdf")}
#'   \item{severity}{Severity of the rule (e.g., "error")}
#'   \item{rule}{The actual rule (e.g., "check_uploadable(MethodologyID) == TRUE")}
#' }
#' 
#' @examples 
#' data("test_rules")
#' 
#' @docType data
#' @keywords data
#' @name test_rules
NULL