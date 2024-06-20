# Functions ----
#' @title Generate a data frame with certificate information
#'
#' @description This function creates a data frame with certificate information including the current time,
#' data and rule hashes, package version, and web hash.
#'
#' @param x A list containing `data_formatted` and `rules` elements.
#' @param time the time the certificate is generated, can be passed a value or uses current system time.
#' @return A data frame with certificate information.
#' @importFrom digest digest
#' @importFrom shiny isTruthy
#' @importFrom utils packageVersion sessionInfo
#' @examples
#' \donttest{
#' certificate_df(x = list(data_formatted = data.frame(a = 1:3, b = 4:6),
#'                         rules = validate::validator(a > 0, b > 0)),
#'                time = Sys.time())
#'                }
#' 
#' @export
certificate_df <- function(x, time = Sys.time()){
    formatted_time <- format(as.POSIXlt(time, origin = "1970-01-01", tz = "GMT"), "%Y-%m-%d %H:%M:%S")
    data.frame(time = formatted_time,
               data = digest(x$data_formatted),
               rules = digest(x$rules),
               package_version = paste(unlist(packageVersion("validate")), collapse = ".", sep = ""),
               web_hash = digest(paste(sessionInfo(),
                                       Sys.time(),
                                       Sys.info())))
}

#' @title Read rules from a file
#'
#' @description
#' This function reads rules from a file or a data frame.
#' The file can be in csv or xlsx format.
#' The data should have the column names "name", "description", "dataset", "valid example", "severity", "rule".
#' The function also checks that the rules do not contain sensitive words and that
#' all the rules fields are character type.
#'
#' @param file_rules The file containing the rules. Can be a CSV or XLSX file, or a data frame.
#'
#' @examples
#' \dontrun{
#' read_rules("path/to/rules")
#' }
#'
#' @return A data frame containing the rules.
#' @export
read_rules <- function(file_rules){
    # Reads the rules file.
    if(is.data.frame(file_rules)){
        rules <- file_rules
    }
    else{
        if(grepl("(\\.csv$)", ignore.case = TRUE, as.character(file_rules))){
            rules <- read.csv(file_rules)
        }
        else if(grepl("(\\.xlsx$)", ignore.case = TRUE, as.character(file_rules))){
            rules <- read_excel(file_rules)
        }
        else{
            stop('Uploaded rules format is not currently supported, please provide a rules file in csv or xlsx format.')  
        }
    }
    
    # Test that rules file has the correct required column names.
    if (!all(c("name", "description", "severity", "rule") %in% names(rules))) {
        stop('Uploaded rules format is not currently supported, please provide a rules file with column names, "name", "description", "severity", "rule".')
    }
    
    # Tests that the rules do not contain sensitive words that may be malicious.
    if (any(grepl("config|secret", rules$rule))) {
        stop('At this time we are unable to support any rules with the words "config" or "secret" in them as they could be malicious.')
    }
    
    # Tests that the rules severity is only warning or error
    if (!all(grepl("(error)|(warning)", rules$severity))) {
        stop('severity in the rules file can only be "error" or "warning"')
    }
    
    # Checks that all the rules fields are character type.
    if (!all(sapply(rules, is.character))) {
        stop('Uploaded rules format is not currently supported, please provide a rules file with columns that are all character type.')
    }
    
    return(rules)
}

#' @title Read and format data from csv or xlsx files
#'
#' @param files_data List of files to be read
#' @param data_names Optional vector of names for the data frames
#' @importFrom readxl excel_sheets
#' @examples
#' read_data(files_data = valid_example, data_names = c("methodology", "particles", "samples"))
#' 
#' @return A list of data frames
#' @export
read_data <- function(files_data, data_names = NULL){
    # Read in all csv files from files_data as a list.
    if(is.list(files_data)){
        data_formatted <- files_data
    }
    else{
        if(all(grepl("(\\.csv$)", ignore.case = T, as.character(files_data)))){
            data_formatted <- tryCatch(lapply(files_data, function(x){read.csv(x)}),
                                       warning = function(w) {warning(w$message)},
                                       error = function(e) {stop(e$message)})
        }
        
        else if(all(grepl("(\\.xlsx$)", ignore.case = T, as.character(files_data)))){
            if(length(as.character(files_data)) > 1){
                data_formatted <- tryCatch(lapply(files_data, function(x){read_excel(x)}),
                                           warning = function(w) {warning(w$message)},
                                           error = function(e) {stop(e$message)})
                message("When multiple Excel files are uploaded only the first sheet from each is used.")
            }
            if(length(as.character(files_data)) == 1){
                sheets <- excel_sheets(files_data)
                sheets <- sheets[!sheets %in% c("LOOKUP", "RULES")]
                if(is.null(data_names)){
                    data_names <- sheets
                }
                data_formatted <- tryCatch(lapply(sheets, function(x){read_excel(files_data, sheet =  x)}),
                                           warning = function(w) {warning(w$message)},
                                           error = function(e) {stop(e$message)})    
            }
        }
        
        else{
            stop("You cannot mix data types, choose either csv or xlsx for all datasets.")
        }    
    }
    
    #Check if there is a warning when reading in the data.
    if (inherits(data_formatted, "simpleWarning") | inherits(data_formatted, "simpleError")){
        stop(paste0("There was an error that said ", data_formatted$message))
    }
    
    #Names the data with the file names.
    names(data_formatted) <- name_data(files_data, data_names)
    
    data_formatted
}

#' @title Name datasets
#'
#' @description This function extracts the names of the datasets provided in the input files.
#' If specific data names are provided, they are used, otherwise the function tries
#' to extract the names from the files themselves.
#'
#' @param files_data A vector of file paths or list of data frames.
#' @param data_names A vector of names to be assigned to datasets.
#'
#' @return A vector of dataset names.
#' @examples
#' name_data(files_data = c("path/to/data1.csv", "path/to/data2.csv"))
#' name_data(files_data = c("path/to/data.xlsx"), data_names = c("sheet1", "sheet2"))
#'
#' @importFrom readxl excel_sheets
#'
#' @export
name_data <- function(files_data, data_names = NULL){
    #Grab the names of the datasets.
    if(isTruthy(data_names)){
        data_names <- gsub("(\\..*$)", "", gsub("(.*/)", "", data_names))
    }
    else if(all(grepl("(\\.xlsx$)", ignore.case = T, as.character(files_data))) & length(as.character(files_data)) == 1){
        data_names <- excel_sheets(files_data)
    }
    else{
        data_names <- gsub("(\\..*$)", "", gsub("(.*/)", "", files_data))
    }
    data_names
}


#' @title Reformat the rules
#'
#' @description This function is responsible for handling the rule reformating, dataset handling
#' and foreign key checks.
#'
#' @param rules A data.frame containing rules to be reformatted.
#' @param data_formatted A named list of data.frames with data.
#' @param zip_data A file path to a zip folder with additional data to check.
#' @importFrom dplyr filter mutate bind_rows
#' @importFrom data.table rbindlist
#' @return A data.frame with reformatted rules.
#' @examples
#' data("test_rules")
#' data("valid_example")
#' reformat_rules(rules = test_rules, data_formatted = valid_example)
#' @export
reformat_rules <- function(rules, data_formatted, zip_data = NULL){
    #Add dataset if one doesn't exist so that everything else works.
    if (!"dataset" %in% names(rules)){
        rules <- rules |>
            mutate(dataset = names(data_formatted))
    }
    
    #Check for special function checking additional files
    rules <- rules |>
        dplyr::mutate(rule = ifelse(grepl("check_exists_in_zip(.*)", .data$rule),
                                    paste0('check_exists_in_zip(zip_path = "', zip_data, '", file_name = ', gsub("(check_exists_in_zip\\()|(\\))", "", .data$rule), ') == TRUE'),
                                    .data$rule))
    
    #Circle back to add logic for multiple dfs
    #Check for special character "___" which is for assessing every column.
    
    do_to_all <- rules |>
        dplyr::filter(grepl("___", .data$rule))
    
    if(nrow(do_to_all) > 0){
        rules <- lapply(names(data_formatted), function(x){
            rules_sub <- do_to_all |> dplyr::filter(.data$dataset == x)
            lapply(colnames(data_formatted[[x]]), function(new_name){
                rules_sub |>
                    dplyr::mutate(rule = gsub("___", new_name, .data$rule)) |>
                    dplyr::mutate(name = paste0(new_name, "_", .data$name))}) |>
                data.table::rbindlist()}) |>
            data.table::rbindlist() |>
            dplyr::bind_rows(rules |> dplyr::filter(!grepl("___", .data$rule)))
    }
    
    # Check special character of is_foreign_key and if so then testing that foreign keys are exact.
    foreign_keys <- rules |>
        dplyr::filter(grepl("is_foreign_key(.*)", .data$rule))
    
    if(nrow(foreign_keys) > 0){
        columns <- gsub("(is_foreign_key\\()|(\\))", "", foreign_keys[["rule"]])
        
        rules <- lapply(1:nrow(foreign_keys), function(x){
            foreign_keys[x,] |>
                mutate(rule = paste0(columns[x],
                                     ' %in% c("',
                                     paste(
                                         lapply(data_formatted, function(y){
                                             y[[columns[x]]]
                                         }) |>
                                             unlist() |>
                                             unique(),
                                         collapse = '", "',
                                         sep = ""),
                                     '")'))
        }) |>
            rbindlist() |>
            bind_rows(rules |> filter(!grepl("is_foreign_key(.*)", .data$rule)))
    }
    rules
}


#' @title Validate data based on specified rules
#'
#' @param files_data A list of file paths for the datasets to be validated.
#' @param data_names (Optional) A character vector of names for the datasets. If not provided, names will be extracted from the file paths.
#' @param file_rules A file path for the rules file, either in .csv or .xlsx format.
#' @param zip_data A file path to a zip folder for validating unstructured data.
#'
#' @return A list containing the following elements:
#'   - data_formatted: A list of data frames with the validated data.
#'   - data_names: A character vector of dataset names.
#'   - report: A list of validation report objects for each dataset.
#'   - results: A list of validation result data frames for each dataset.
#'   - rules: A list of validator objects for each dataset.
#'   - status: A character string indicating the overall validation status ("success" or "error").
#'   - issues: A logical vector indicating if there are any issues in the validation results.
#'   - message: A data.table containing information about any issues encountered.
#'
#' @examples
#' # Validate data with specified rules
#' data("valid_example")
#' data("invalid_example")
#' data("test_rules")
#'
#' result_valid <- validate_data(files_data = valid_example,
#'                         data_names = c("methodology", "particles", "samples"),
#'                         file_rules = test_rules)
#'                        
#' result_invalid <- validate_data(files_data = invalid_example,
#'                         data_names = c("methodology", "particles", "samples"),
#'                         file_rules = test_rules)
#'
#' @importFrom data.table data.table rbindlist
#' @importFrom readxl read_excel excel_sheets
#' @importFrom dplyr left_join mutate filter bind_rows across everything
#' @import validate
#' @importFrom shiny isTruthy
#' @importFrom utils read.csv
#' @export
validate_data <- function(files_data, data_names = NULL, file_rules = NULL, zip_data = NULL) {
    if(check_for_malicious_files(c(files_data, file_rules))){
        stop(paste("Data or rules files cannot be of any of these types:", "_exe", "a6p", "ac", "acr", "action", "air", "apk", "app",
                   "applescript", "awk", "bas", "bat", "bin", "cgi", "chm",
                   "cmd", "com", "cpl", "crt", "csh", "dek", "dld", "dll",
                   "dmg", "drv", "ds", "ebm", "elf", "emf", "esh", "exe",
                   "ezs", "fky", "frs", "fxp", "gadget", "gpe", "gpu", "hlp",
                   "hms", "hta", "icd", "iim", "inf", "ins", "inx", "ipa",
                   "ipf", "isp", "isu", "jar", "js", "jse", "jsp", "jsx",
                   "kix", "ksh", "lib", "lnk", "mcr", "mel", "mem", "mpkg",
                   "mpx", "mrc", "ms", "msc", "msi", "msp", "mst", "mxe",
                   "obs", "ocx", "pas", "pcd", "pex", "pif", "pkg", "pl",
                   "plsc", "pm", "prc", "prg", "pvd", "pwc", "py", "pyc",
                   "pyo", "qpx", "rbx", "reg", "rgs", "rox", "rpj", "scar",
                   "scpt", "scr", "script", "sct", "seed", "sh", "shb",
                   "shs", "spr", "sys", "thm", "tlb", "tms", "u3p", "udf",
                   "url", "vb", "vbe", "vbs", "vbscript", "vdo", "vxd",
                   "wcm", "widget", "wmf", "workflow", "wpk", "ws", "wsc",
                   "wsf", "wsh", "xap", "xqt", "zlq"))
    }
    if(!is.null(zip_data)){
        if(check_for_malicious_files(utils::unzip(zip_data, list = T)$Name)){
            stop(paste("Data or rules files cannot be of any of these types:",
                       "_exe", "a6p", "ac", "acr", "action", "air", "apk", "app",
                       "applescript", "awk", "bas", "bat", "bin", "cgi", "chm",
                       "cmd", "com", "cpl", "crt", "csh", "dek", "dld", "dll",
                       "dmg", "drv", "ds", "ebm", "elf", "emf", "esh", "exe",
                       "ezs", "fky", "frs", "fxp", "gadget", "gpe", "gpu", "hlp",
                       "hms", "hta", "icd", "iim", "inf", "ins", "inx", "ipa",
                       "ipf", "isp", "isu", "jar", "js", "jse", "jsp", "jsx",
                       "kix", "ksh", "lib", "lnk", "mcr", "mel", "mem", "mpkg",
                       "mpx", "mrc", "ms", "msc", "msi", "msp", "mst", "mxe",
                       "obs", "ocx", "pas", "pcd", "pex", "pif", "pkg", "pl",
                       "plsc", "pm", "prc", "prg", "pvd", "pwc", "py", "pyc",
                       "pyo", "qpx", "rbx", "reg", "rgs", "rox", "rpj", "scar",
                       "scpt", "scr", "script", "sct", "seed", "sh", "shb",
                       "shs", "spr", "sys", "thm", "tlb", "tms", "u3p", "udf",
                       "url", "vb", "vbe", "vbs", "vbscript", "vdo", "vxd",
                       "wcm", "widget", "wmf", "workflow", "wpk", "ws", "wsc",
                       "wsf", "wsh", "xap", "xqt", "zlq"))
        }
    }
    
    rules <- read_rules(file_rules)
    
    data_formatted <- read_data(files_data = files_data, data_names = data_names)
    
    if (!"dataset" %in% names(rules) & length(names(data_formatted)) > 1) {
        stop("If there is more than one dataset then a dataset column must be specified in the rules file to describe which rule applies to which dataset.")
    }
    
    if ("dataset" %in% names(rules)) {
        if (!all(unique(rules$dataset) %in% names(data_formatted))) {
            stop(paste0("If there is a dataset column in the rules file it needs to pertain to the names of the datasets being tested. The rules file lists datasets ", paste(setdiff(unique(rules$dataset), names(data_formatted)), collapse = ", "),  " that do not match the datasets shared."))
        }
    }
    
    rules <- reformat_rules(rules = rules, data_formatted = data_formatted, zip_data = zip_data)
    
    rules_formatted <- tryCatch(validate::validator(.data=rules),
                                warning = function(w) {
                                    warning(w)
                                    NULL
                                },
                                error = function(e) {
                                    stop(e)
                                })
    
    if (is.null(rules_formatted) || (length(class(rules_formatted)) != 1 || !inherits(rules_formatted, "validator"))) {
        stop("There was an error with reading the rules file.")
    }
    
    all_variables <- unique(c(validate::variables(rules_formatted), unlist(lapply(data_formatted, names))))
    
    if (!(all(all_variables %in% validate::variables(rules_formatted)) & all(all_variables %in% unlist(lapply(data_formatted, names))))) {
        warning(paste0("All variables in the rules csv should be in the data csv and vice versa for the validation to work correctly. Download the Data Template for an example of correctly formatted upload. Ignoring these unmatched variables ", paste0(all_variables[!(all_variables %in% validate::variables(rules_formatted)) | !(all_variables %in% unlist(lapply(data_formatted, names)))], collapse = ", ")))
    }
    
    report <- lapply(names(data_formatted), function(x){
        validate::confront(data_formatted[[x]], validate::validator(.data=rules |> dplyr::filter(.data$dataset == x)))
    })
    
    results <- lapply(report, function(x) {
        validate::summary(x) |>
            dplyr::left_join(rules, by = "name") |>
            dplyr::mutate(status = ifelse((.data$fails > 0 & .data$severity == "error") | .data$error | .data$warning , "error", "success")) |>
            mutate(status = ifelse(.data$fails > 0 & .data$severity == "warning", "warning", .data$status))
    })
    
    any_issues <- vapply(results, function(x) {
        any(x$status == "error")
    }, FUN.VALUE = TRUE)
    
    rules_list_formatted <- tryCatch(lapply(names(data_formatted), function(x) {
        validator(.data=rules |> filter(.data$dataset == x))
    }),
    warning = function(w) {
        warning(w)
        NULL
    },
    error = function(e) {
        stop(e)
    })
    
    list(data_formatted = data_formatted,
         data_names = names(data_formatted),
         zip_data = if(exists("zip_data")){zip_data} else{NULL},
         report = report,
         results = results,
         rules = rules_list_formatted,
         issues = any_issues)
}

#' @title Share your validated data
#'
#' @description This function uploads validated data to specified remote repositories,
#' such as CKAN, Amazon S3, and/or MongoDB.
#'
#' @param validation A list containing validation information.
#' @param data_formatted A list containing formatted data.
#' @param files A vector of file paths to upload.
#' @param verified The secret key provided by the portal maintainer.
#' @param valid_rules A list of valid rules for the dataset.
#' @param valid_key_share A valid key to share data.
#' @param ckan_url The URL of the CKAN instance.
#' @param ckan_key The API key for the CKAN instance.
#' @param ckan_package The CKAN package to which the data will be uploaded.
#' @param url_to_send The URL to send the data.
#' @param rules A set of rules used for validation.
#' @param results A list containing results of the validation.
#' @param s3_key_id AWS ACCESS KEY ID
#' @param s3_secret_key AWS SECRET ACCESS KEY
#' @param s3_region AWS DEFAULT REGION
#' @param s3_bucket The name of the Amazon S3 bucket.
#' @param old_cert (Optional) An old certificate to be uploaded alongside the new one to override the previous submission with.
#' @param mongo_key mongo connection url
#' @param mongo_collection collection name
#'
#' @return A list containing the status and message of the operation.
#'
#' @importFrom data.table data.table fwrite
#' @importFrom digest digest
#' @importFrom ckanr ckanr_setup resource_create
#' @importFrom aws.s3 put_object
#' @importFrom utils write.csv read.csv zip
#' @import mongolite
#' @import jsonlite
#' @examples
#' \dontrun{
#' shared_data <- remote_share(validation = result_valid,
#'                             data_formatted = result_valid$data_formatted,
#'                             files = test_file,
#'                             verified = "your_verified_key",
#'                             valid_key_share = "your_valid_key_share",
#'                             valid_rules = digest::digest(test_rules),
#'                             ckan_url = "https://example.com",
#'                             ckan_key = "your_ckan_key",
#'                             ckan_package = "your_ckan_package",
#'                             url_to_send = "https://your-url-to-send.com",
#'                             rules = test_rules,
#'                             results = valid_example$results,
#'                             s3_key_id = "your_s3_key_id",
#'                             s3_secret_key = "your_s3_secret_key",
#'                             s3_region = "your_s3_region",
#'                             s3_bucket = "your_s3_bucket",
#'                             mongo_key = "your_mongo_key",
#'                             mongo_collection = "your_mongo_collection",
#'                             old_cert = NULL
#' )
#' }
#' @export

remote_share <- function(validation, data_formatted, files, verified, valid_rules, valid_key_share, ckan_url, ckan_key, ckan_package, url_to_send, rules, results, s3_key_id, s3_secret_key, s3_region, s3_bucket, mongo_key, mongo_collection, old_cert = NULL){
    
    use_ckan <- isTruthy(ckan_url) & isTruthy(ckan_key) & isTruthy(ckan_package)
    use_s3 <- isTruthy(s3_bucket)
    use_mongodb <- isTruthy(mongo_key) & isTruthy(mongo_collection)
    
    if(!(use_ckan| use_s3| use_mongodb)){
        stop("Upload will not work because no upload methods are specified.")
    }
    
    if(any(validation$issues)){
        stop("There are errors in the dataset that persist. Until all errors are remedied, the data cannot be uploaded to the remote repository.")
    }
    
    if(!any(digest(as.data.frame(rules)) %in% valid_rules)){
        stop("If you are using a key to upload data to a remote repo then there must be a valid pair with the rules you are using in our internal database.")
    }
    
    if(!any(verified %in% valid_key_share)){
        stop("You must have a valid key provided by the portal maintainer to use this feature.")
    }
    
    hashed_data <- digest(data_formatted)
    
    structured_files <- paste0(tempdir(), "\\", hashed_data, ".rds")
    
    saveRDS(data_formatted, file = structured_files)
    
    submission_time <- as.double(as.POSIXlt(Sys.time(), "GMT"))
    
    if(use_ckan){
        ckanr::ckanr_setup(url = ckan_url, key = ckan_key)
    }    
    
    if(use_s3){
        Sys.setenv(
            "AWS_ACCESS_KEY_ID" = s3_key_id,
            "AWS_SECRET_ACCESS_KEY" = s3_secret_key,
            "AWS_DEFAULT_REGION" = s3_region
        )
    }
    
    
    #Add certificate
    certificate_file <- paste0(tempdir(), "\\", "certificate.csv")
    certificate <- certificate_df(validation, time = submission_time)
    data.table::fwrite(certificate, certificate_file)
    
    data_formatted2 <- data_formatted
    data_formatted2$certificate <- certificate
    data_formatted2 <- toJSON(data_formatted2)
    
    if(use_mongodb) {
        mongo_conn <- mongo(collection = mongo_collection, url = mongo_key)
        mongo_conn$insert(data_formatted2)
        
        message(paste0("Data was successfully sent to the data portal at ", mongo_collection))
    }
    
    files = c(files, structured_files, certificate_file)
    
    #Add old certificate
    if(isTruthy(old_cert)){
        files = c(files, old_cert)
    }
    
    temp_zip <- paste0(tempdir(), "\\", "temp.zip")
    
    zip(zipfile = temp_zip, files = files, extras = '-j') # Zip the test file
    
    if(use_s3){
        put_object(
            file = temp_zip,
            object = paste0(hashed_data, ".zip"),
            bucket = s3_bucket
        )
        
        message(paste0("Data was successfully sent to the data portal at ", s3_bucket))
    }
    
    if(use_ckan){
        resource_create(package_id = ckan_package,
                        description = "validated raw data upload to microplastic data portal",
                        name = paste0(hashed_data, ".zip"),
                        upload = temp_zip)
        
        message(paste0("Data was successfully sent to the data portal at ", url_to_send))
    }
    
    
    return(list(hashed_data = hashed_data,
                submission_time = submission_time))
}

#' @title Download structured data from remote sources
#'
#' @description This function downloads data from remote sources like CKAN, AWS S3, and MongoDB.
#' It retrieves the data based on the hashed_data identifier and assumes the data is stored using the same naming conventions provided in the `remote_share` function.
#'
#' @param hashed_data A character string representing the hashed identifier of the data to be downloaded.
#' @param ckan_url A character string representing the CKAN base URL.
#' @param ckan_key A character string representing the CKAN API key.
#' @param ckan_package A character string representing the CKAN package identifier.
#' @param s3_key_id A character string representing the AWS S3 access key ID.
#' @param s3_secret_key A character string representing the AWS S3 secret access key.
#' @param s3_region A character string representing the AWS S3 region.
#' @param s3_bucket A character string representing the AWS S3 bucket name.
#' @param mongo_key A character string representing the mongo key.
#' @param mongo_collection A character string representing the mongo collection.
#'
#' @importFrom shiny isTruthy
#' @importFrom dplyr mutate_if
#' @importFrom aws.s3 get_bucket get_object save_object
#' @importFrom ckanr ckanr_setup package_show ckan_fetch
#' @importFrom readr read_rds
#' @import mongolite
#'
#'
#' @return A named list containing the downloaded datasets.
#'
#' @examples
#' \dontrun{
#'   downloaded_data <- remote_download(hashed_data = "example_hash",
#'                                      ckan_url = "https://example.com",
#'                                      ckan_key = "your_ckan_key",
#'                                      ckan_package = "your_ckan_package",
#'                                      s3_key_id = "your_s3_key_id",
#'                                      s3_secret_key = "your_s3_secret_key",
#'                                      s3_region = "your_s3_region",
#'                                      s3_bucket = "your_s3_bucket",
#'                                      mongo_key = "mongo_key",
#'                                      mongo_collection = "mongo_collection")
#' }
#'
#' @export
remote_download <- function(hashed_data = NULL, ckan_url, ckan_key, ckan_package, s3_key_id, s3_secret_key, s3_region, s3_bucket, mongo_key, mongo_collection) {
    
    use_ckan <- shiny::isTruthy(ckan_url) & shiny::isTruthy(ckan_key) & shiny::isTruthy(ckan_package)
    use_s3 <- shiny::isTruthy(s3_bucket)
    use_mongodb <- shiny::isTruthy(mongo_key) & shiny::isTruthy(mongo_collection)
    
    if(use_ckan){
        ckanr::ckanr_setup(url = ckan_url, key = ckan_key)
    }
    
    if(use_s3){
        Sys.setenv(
            "AWS_ACCESS_KEY_ID" = s3_key_id,
            "AWS_SECRET_ACCESS_KEY" = s3_secret_key,
            "AWS_DEFAULT_REGION" = s3_region
        )
    }
    
    if(use_mongodb) {
        mongo_conn <- mongo(collection = mongo_collection, url = mongo_key)
    }
    
    data_downloaded <- list()
    
    if(use_s3){
        # Retrieve a list of objects from S3 bucket
        s3_objects <- get_bucket(bucket = s3_bucket, prefix = hashed_data)
        file <- tempfile(pattern = "temp", fileext = ".zip")
        aws.s3::save_object(object = s3_objects[[1]]$Key, file = file, bucket = s3_bucket)
        zip_files <- unzip(file, list = TRUE, exdir = tempdir())$Name
        structured_data <- zip_files[grepl(".rds$", zip_files)]
        unzip(file, files = structured_data, exdir = tempdir())
        data_downloaded[["s3"]] <- read_rds(paste0(tempdir(),"/", structured_data))
    }
    
    if(use_ckan){
        resources <- package_show(ckan_package)$resources
        resources_names <- vapply(resources, function(x){x$name}, FUN.VALUE = character(1))
        hashed_data_resources <- resources[grepl(hashed_data, resources_names)]
        file <- tempfile(pattern = "temp", fileext = ".zip")
        ckan_fetch(x = hashed_data_resources[[length(hashed_data_resources)]]$url, store = "disk", path = file)
        zip_files <- unzip(file, list = TRUE, exdir = tempdir())$Name
        structured_data <- zip_files[grepl(".rds$", zip_files)]
        unzip(file, files = structured_data, exdir = tempdir())
        data_downloaded[["ckan"]] <- read_rds(paste0(tempdir(),"/", structured_data))
    }
    
    if(use_mongodb){
        mongo_query <- toJSON(list("unique_id" = hashed_data))
        mongo_data <- mongo_conn$find(query = mongo_query)
        data_downloaded[["mongodb"]] <- mongo_data
    }
    return(data_downloaded)
}

#' @title Download raw data from remote sources
#'
#' @description This function downloads data from remote sources like CKAN and AWS S3.
#' It retrieves the data based on the hashed_data identifier and assumes the data is stored using the same naming conventions provided in the `remote_share` function.
#'
#' @param hashed_data A character string representing the hashed identifier of the data to be downloaded.
#' @param file_path location and name of the zip file to create.
#' @param ckan_url A character string representing the CKAN base URL.
#' @param ckan_key A character string representing the CKAN API key.
#' @param ckan_package A character string representing the CKAN package identifier.
#' @param s3_key_id A character string representing the AWS S3 access key ID.
#' @param s3_secret_key A character string representing the AWS S3 secret access key.
#' @param s3_region A character string representing the AWS S3 region.
#' @param s3_bucket A character string representing the AWS S3 bucket name.
#'
#' @importFrom shiny isTruthy
#' @importFrom aws.s3 get_bucket get_object save_object
#' @importFrom ckanr ckanr_setup package_show ckan_fetch
#'
#' @return Any return objects from the downloads.
#'
#' @examples
#' \dontrun{
#'   downloaded_data <- remote_raw_download(hashed_data = "example_hash",
#'                                      file_path = "your/path/file.zip",
#'                                      ckan_url = "https://example.com",
#'                                      ckan_key = "your_ckan_key",
#'                                      ckan_package = "your_ckan_package",
#'                                      s3_key_id = "your_s3_key_id",
#'                                      s3_secret_key = "your_s3_secret_key",
#'                                      s3_region = "your_s3_region",
#'                                      s3_bucket = "your_s3_bucket")
#' }
#'
#' @export
remote_raw_download <- function(hashed_data = NULL, file_path = NULL, ckan_url = NULL, ckan_key = NULL, ckan_package = NULL, s3_key_id = NULL, s3_secret_key = NULL, s3_region = NULL, s3_bucket = NULL) {
    
    use_ckan <- shiny::isTruthy(ckan_url) & shiny::isTruthy(ckan_key) & shiny::isTruthy(ckan_package)
    use_s3 <- shiny::isTruthy(s3_bucket)  
    
    if(use_ckan & use_s3){
        stop("This downloader only supports downloading files from S3 or CKAN, not both. The files are identical so there isn't a need to download both.")
    }
    
    if(use_ckan){
        ckanr::ckanr_setup(url = ckan_url, key = ckan_key)
    }
    
    if(use_s3){
        Sys.setenv(
            "AWS_ACCESS_KEY_ID" = s3_key_id,
            "AWS_SECRET_ACCESS_KEY" = s3_secret_key,
            "AWS_DEFAULT_REGION" = s3_region
        )
    }
    
    if(use_s3){
        # Retrieve a list of objects from S3 bucket
        s3_objects <- get_bucket(bucket = s3_bucket, prefix = hashed_data)
        aws.s3::save_object(object = s3_objects[[1]]$Key, file = file_path, bucket = s3_bucket)
    }
    
    if(use_ckan){
        resources <- package_show(ckan_package)$resources
        resources_names <- vapply(resources, function(x){x$name}, FUN.VALUE = character(1))
        hashed_data_resources <- resources[grepl(hashed_data, resources_names)]
        ckan_fetch(x = hashed_data_resources[[length(hashed_data_resources)]]$url, store = "disk", path = file_path)
    }
}

#' @title Download all data alternative
#' 
#' @description This function allows users to download all data rather than one data set at a time.
#' 
#' @param file_path location and name of the zip file to create.
#' @param s3_key_id A character string representing the AWS S3 access key ID.
#' @param s3_secret_key A character string representing the AWS S3 secret access key.
#' @param s3_region A character string representing the AWS S3 region.
#' @param s3_bucket A character string representing the AWS S3 bucket name.
#' @param callback Prints if the download was a success.
#' 
#' @importFrom shiny isTruthy
#' @importFrom aws.s3 get_bucket get_object save_object
#' @importFrom ckanr ckanr_setup package_show ckan_fetch
#'
#' @return Any return objects from the downloads.
#' 
#' @examples
#' \dontrun{
#'     download_all_data <- download_all(file_path = "your/path/file.zip",
#'                                       s3_key_id = "your_s3_key_id",
#'                                       s3_secret_key = "your_s3_secret_key",
#'                                       s3_region = "your_s3_region",
#'                                       s3_bucket = "your_s3_bucket",
#'                                       callback = NULL)
#' }
#' 
#' @export
download_all <- function(file_path = NULL, s3_key_id = NULL, s3_secret_key = NULL, s3_region = NULL, s3_bucket = NULL, callback = NULL) {
    use_s3 <- shiny::isTruthy(s3_bucket)
    
    if (use_s3) {
        Sys.setenv(
            "AWS_ACCESS_KEY_ID" = s3_key_id,
            "AWS_SECRET_ACCESS_KEY" = s3_secret_key,
            "AWS_DEFAULT_REGION" = s3_region
        )
        # Retrieve a list of objects from S3 bucket
        s3_objects <- get_bucket(bucket = s3_bucket)
        for (object in s3_objects) {
            success <- tryCatch({
                aws.s3::save_object(object = object$Key, file = file.path(file_path, basename(object$Key)), bucket = s3_bucket)
                TRUE  # Return TRUE if download is successful
            }, error = function(e) {
                FALSE  # Return FALSE if an error occurs during download
            })
        }
        
        # Call the callback function with the success status
        if (!is.null(callback)) {
            callback(success)
        }
    }
}

#' @title Check if an object is of class POSIXct
#'
#' @description This function checks if the given object is of class POSIXct.
#' It returns TRUE if the object inherits the POSIXct class, otherwise FALSE.
#'
#' @param x An object to be tested for POSIXct class inheritance.
#' @return A logical value indicating if the input object is of class POSIXct.
#' @examples
#' x <- as.POSIXct("2021-01-01")
#' is.POSIXct(x) # TRUE
#'
#' y <- Sys.Date()
#' is.POSIXct(y) # FALSE
#'
#' @export
is.POSIXct <- function(x) inherits(x, "POSIXct")

#' Check which rules were broken
#'
#' Filter the results of validation to show only broken rules, optionally including successful decisions.
#'
#' @param results A data frame with validation results.
#' @param show_decision A logical value to indicate if successful decisions should be included in the output.
#'
#' @return A data frame with the filtered results.
#' @importFrom dplyr filter select everything
#' @export
#'
#' @examples
#' # Sample validation results data frame
#' sample_results <- data.frame(
#'   description = c("Rule 1", "Rule 2", "Rule 3"),
#'   status = c("error", "success", "error"),
#'   name = c("rule1", "rule2", "rule3"),
#'   expression = c("col1 > 0", "col2 <= 5", "col3 != 10"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Show only broken rules
#' broken_rules <- rules_broken(sample_results, show_decision = FALSE)
#' @export
rules_broken <- function(results, show_decision){
    results |>
        dplyr::filter(if(show_decision){.data$status %in% c("error", "warning")} else{.data$status %in% c("error", "warning", "success")}) |>
        select("description", "status", "name", "expression", everything())
}

#' @title Check which rows in the data violated the rules
#'
#' @description Get the rows in the data that violate the specified rules.
#'
#' @param data_formatted A formatted data frame.
#' @param report A validation report generated by the 'validate' function.
#' @param broken_rules A data frame with broken rules information.
#' @param rows A vector of row indices specifying which rules from the suite of rules with errors to check for violations.
#'
#' @return A data frame with rows in the data that violate the specified rules.
#' @importFrom validate violating validator confront
#' @export
#'
#' @examples
#' data("invalid_example")
#' data("test_rules")
#' # Generate a validation report
#' result_invalid <- validate_data(files_data = invalid_example,
#'                         data_names = c("methodology", "particles", "samples"),
#'                         file_rules = test_rules)
#'
#' # Find the broken rules
#' broken_rules <- rules_broken(results = result_invalid$results[[1]], show_decision = TRUE)
#'
#' # Get rows for the specified rules
#' violating_rows <- rows_for_rules(data_formatted = result_invalid$data_formatted[[1]],
#'                                  report = result_invalid$report[[1]],
#'                                  broken_rules = broken_rules,
#'                                  rows = 1)
#' @export
rows_for_rules <- function(data_formatted,
                           report,
                           broken_rules,
                           rows){
    tryCatch({
        violating(data_formatted, report[broken_rules[rows, "name"]])
    }, warning = function(w) {
        if(broken_rules[rows, "items"] == 0){
            warning("Column being assessed by the rule is not in the dataset.")
            return(data_formatted)
        }
        if(broken_rules[rows, "items"] == 1 & nrow(data_formatted) != 1){
            warning("This rule applies to the entire dataset.")
            return(data_formatted)
        }
        
    }, error = function(e) {
        if(broken_rules[rows, "items"] == 0){
            warning("Column being assessed by the rule is not in the dataset.")
            return(data_formatted)
        }
        if(broken_rules[rows, "items"] == 1 & nrow(data_formatted) != 1){
            warning("This rule applies to the entire dataset.")
            return(data_formatted)
        }
    })
}

#acknowledgement https://github.com/adamjdeacon/checkLuhn/blob/master/R/checkLuhn.R
#' @title Check if a number passes the Luhn algorithm
#'
#' @description This function checks if a given number passes the Luhn algorithm. It is commonly used to validate credit card numbers.
#' @param number A character string of the number to check against the Luhn algorithm.
#' @return A logical value indicating whether the number passes the Luhn algorithm (TRUE) or not (FALSE).
#' @examples
#' checkLuhn("4532015112830366") # TRUE
#' checkLuhn("4532015112830367") # FALSE
#' @export
checkLuhn <- function(number) {
    # must have at least 2 digits
    if(nchar(number) <= 2) {
        return(FALSE)
    }
    
    # strip spaces
    number <- gsub("-", "", gsub(pattern = " ", replacement = "", number))
    
    # Return FALSE if not a number
    if (!grepl("^[[:digit:]]+$", number)) {
        return(FALSE)
    }
    
    # split the string, convert it to a list, and reverse it
    digits <- unlist(strsplit(number, ""))
    digits <- digits[length(digits):1]
    
    to_replace <- seq(2, length(digits), 2)
    digits[to_replace] <- as.numeric(digits[to_replace]) * 2
    
    # gonna do some maths, let's convert it to numbers
    digits <- as.numeric(digits)
    
    # a digit cannot be two digits, so any that are greater than 9, subtract 9 and
    # make the world a better place
    digits <- ifelse(digits > 9, digits - 9, digits)
    
    # does the sum divide by 10?
    ((sum(digits) %% 10) == 0)
}

#' @title Check if a file exists in a zip file
#'
#' @description This function checks if a file with a given name exists in a specified zip file.
#' 
#' @param zip_path A character string representing the path of the zip file.
#' @param file_name A character string representing the name of the file to check.
#' @return A logical value indicating whether the file exists in the zip file (TRUE) or not (FALSE).
#' @importFrom utils unzip
#' @examples
#' \dontrun{
#' check_exists_in_zip(zip_path = "/path/to/your.zip", file_name = "file/in/zip.csv")
#' }
#' @export
check_exists_in_zip <- function(zip_path, file_name) {
    if(is.null(zip_path) || zip_path == "") return(rep(FALSE, length(file_name)))
    # List files in the zip
    zip_files <- unzip(zip_path, list = TRUE)$Name
    # Check if file_name is in the list of files
    file_exists <- file_name %in% zip_files
    return(file_exists)
}

#' @title Check and format image URLs
#'
#' @description This function checks if the input string contains an image URL (PNG or JPG) and formats it as an HTML img tag with a specified height.
#' 
#' @param x A character string to check for image URLs.
#' @return A character string with the HTML img tag if an image URL is found, otherwise the input string.
#' @examples
#' check_images("https://example.com/image.png")
#' check_images("https://example.com/image.jpg")
#' check_images("https://example.com/text")
#' @export
check_images <- function(x){
    ifelse(grepl("https://.*\\.png|https://.*\\.jpg", x),
           paste0('<img src ="', x, '" height = "50"></img>'),
           x)
}

#' @title Check and format non-image hyperlinks
#'
#' @description This function checks if the input string contains a non-image hyperlink and formats it as an HTML anchor tag.
#' 
#' @param x A character string to check for non-image hyperlinks.
#' @return A character string with the HTML anchor tag if a non-image hyperlink is found, otherwise the input string.
#' @examples
#' check_other_hyperlinks("https://example.com/page")
#' check_other_hyperlinks("https://example.com/image.png")
#' check_other_hyperlinks("https://example.com/image.jpg")
#' @export
check_other_hyperlinks <- function(x){
    ifelse(grepl("https://", x) & !grepl("https://.*\\.png|https://.*\\.jpg", x),
           paste0('<a href ="', x, '">', x, '</a>'),
           x)
}

#' @title Test for profanity in a string
#'
#' @description This function checks if the input string contains any profane words.
#' 
#' @param x A character string to check for profanity.
#' @return A logical value indicating whether the input string contains no profane words.
#' @import lexicon
#' @examples
#' test_profanity("This is a clean sentence.")
#' test_profanity("This sentence contains a badword.")
#' @export
test_profanity <- function(x){
    bad_words <- unique(tolower(c(#lexicon::profanity_alvarez,
        #lexicon::profanity_arr_bad,
        lexicon::profanity_banned#,
        #lexicon::profanity_zac_anger#,
        #lexicon::profanity_racist
    )))
    vapply(bad_words, function(y){
        !grepl(y, x, ignore.case = T)
    }, FUN.VALUE = T) |>
        all()
}

#' @title Create a formatted Excel file based on validation rules
#'
#' @description This function creates an Excel file with conditional formatting and data validation
#' based on the given validation rules in a CSV or Excel file.
#' This function is currently compatible with Windows and Linux operating systems. When using a macOS system,
#' the excel file is able to download, but has some bugs with formatting the LOOKUP sheet.
#' 
#' @param file_rules A CSV or Excel file containing validation rules.
#' @param negStyle Style to apply for negative conditions (default is red text on a pink background).
#' @param posStyle Style to apply for positive conditions (default is green text on a light green background).
#' @param row_num Number of rows to create in the output file (default is 1000).
#' @return A workbook object containing the formatted Excel file.
#' @importFrom readr read_csv
#' @importFrom readxl read_excel
#' @importFrom dplyr filter mutate bind_rows %>%
#' @importFrom data.table rbindlist
#' @importFrom validate validator variables violating
#' @importFrom openxlsx createWorkbook addWorksheet writeData freezePane dataValidation conditionalFormatting saveWorkbook createStyle protectWorksheet
#' @importFrom tibble as_tibble tibble
#' @importFrom utils read.csv
#' @importFrom rlang .data
#' @examples
#' \donttest{
#' data("test_rules")
#' create_valid_excel(file_rules = test_rules)
#' }
#' @export
create_valid_excel <- function(file_rules,
                               negStyle  = createStyle(fontColour = "#9C0006", bgFill = "#FFC7CE"),
                               posStyle  = createStyle(fontColour = "#006100", bgFill = "#C6EFCE"),
                               row_num   = 1000){
    #Reads the rules file.
    if(is.data.frame(file_rules)){
        rules <- file_rules
    }
    else{
        if(grepl("(\\.csv$)", ignore.case = T, as.character(file_rules))){
            rules <- read.csv(file_rules)
        }
        
        if(grepl("(\\.xlsx$)", ignore.case = T, as.character(file_rules))){
            rules <- read_excel(file_rules)
        }
    }
    #Grab the names of the datasets.
    data_names <- if("dataset" %in% names(rules)){
        unique(rules$dataset)
    }
    else{
        name <- gsub("(.*/)|(\\..*)", "", file_rules)
        rules$dataset <- name
        name
    }
    
    #Circle back to add logic for multiple dfs
    #Check for special character "___" which is for assessing every column.
    
    do_to_all <- rules |>
        filter(grepl("___", .data$rule))
    
    if(nrow(do_to_all) > 0){
        rules <- lapply(data_names, function(x){
            rules_sub <- do_to_all |> filter(.data$dataset == x)
            rules_sub_variables <- variables(validator(.data=rules_sub))
            lapply(rules_sub_variables, function(new_name){
                rules_sub |>
                    mutate(rule = gsub("___", new_name, .data$rule)) |>
                    mutate(name = paste0(new_name, "_", .data$name))
            }) |>
                rbindlist()
        }) |>
            rbindlist() |>
            bind_rows(rules |> filter(!grepl("___", .data$rule)))
    }
    
    rules <- rules |>
        mutate(rule = gsub("(is_foreign_key\\()|(check_exists_in_zip\\()", "!is.na\\(", .data$rule))
    
    lookup_column_index <- 1
    wb <- createWorkbook()
    addWorksheet(wb, "RULES")
    writeData(wb, sheet = "RULES", x = rules, startCol = 1)
    for(sheet_num in 1:length(data_names)){ #Sheet level for loop
        rules_all_raw <- rules |> filter(.data$dataset == data_names[sheet_num])
        rules_all <- validator(.data = rules_all_raw)
        rule_variables <- variables(rules_all)
        sheet_name <- data_names[sheet_num]
        addWorksheet(wb, sheet_name)
        freezePane(wb, sheet_name, firstRow = TRUE) ## shortcut to freeze first row for every table.
        for(col_name in rule_variables){#Setup the column names with empty rows.
            df <- as_tibble(rep("", row_num))
            names(df) <- col_name
            column_index_startup <- which(rule_variables == col_name)
            writeData(wb, sheet = sheet_name, x = df, startCol = column_index_startup)
        }
        for(col_num in 1:length(rules_all)){
            rule_test <- rules_all[[col_num]]
            expression <- rule_test@expr
            column_index <- which(rule_variables == variables(rule_test))
            if(any(grepl("(%vin%)|(%in%)", expression))){
                if(lookup_column_index == 1){
                    addWorksheet(wb, "LOOKUP")
                }
                values <- unlist(strsplit(gsub('(")|(\\))|(.*c\\()', "", as.character(expression[3])), ", "))
                lookup_col <- LETTERS[lookup_column_index]
                df_lookup <- tibble(values)
                names(df_lookup) <- paste0(variables(rule_test), "_lookup")
                writeData(wb,
                          sheet = "LOOKUP",
                          x = df_lookup,
                          startCol = lookup_column_index)
                dataValidation(wb,
                               sheet = sheet_name,
                               cols = column_index,
                               rows = 2:row_num,
                               type = "list",
                               value = paste0("LOOKUP!$", lookup_col, "$2:$", lookup_col, "$", length(values) +1))  
                lookup_column_index = lookup_column_index + 1
            }
            if(any(grepl("is_unique\\(.*\\)", expression))){
                conditionalFormatting(wb,
                                      sheet_name,
                                      cols = column_index,
                                      rows = 2:row_num,
                                      type = "duplicates",
                                      style = negStyle)
            }
            if(sum(grepl("!|is.na(.*)", expression)) == 2){ #Not working yet.
                dataValidation(wb,
                               sheet_name,
                               cols = column_index,
                               rows = 2:row_num,
                               type = "textlength",
                               operator = "greaterThanOrEqual",
                               value = "1",
                               allowBlank = FALSE)
            }
            if(any(grepl("in_range(.*)", expression))){
                dataValidation(wb,
                               sheet_name,
                               cols = column_index,
                               rows = 2:row_num,
                               type = "decimal",
                               operator = "between",
                               value = c(as.numeric(as.character(expression)[grepl("^-|[0-9]+$", as.character(expression))][1]),
                                         as.numeric(as.character(expression)[grepl("^-|[0-9]+$", as.character(expression))][2])))
            }
            if(any(grepl("grepl(.*)", expression))){ #could be improved with begins with and ends with logic.  
                good_conditions <- unlist(strsplit(gsub('(\\[[0-9]*-[0-9]*\\])|(\\])|(\\[)|(\\\\)|(\\^)|(\\$)|(\\))|(\\()', "",  as.character(expression)[2]), split = "\\|"))
                for(contain_condition in good_conditions){
                    conditionalFormatting(wb,
                                          sheet_name,
                                          cols = column_index,
                                          rows = 2:row_num,
                                          type = "contains",
                                          rule = contain_condition,
                                          style = posStyle)
                }
            }
            if(any(grepl("(%vin%)|(%in%)", expression))){
                protectWorksheet(
                    wb,
                    "LOOKUP",
                    protect = TRUE) #Protects the lookup table without a password just to prevent accidents.
            }
            #Need better way to deal with foreign keys, currently not working well.
            
        }
    }
    wb
}

#' @title Check for malicious files
#'
#' @description This function checks for the presence of files with extensions known to be associated with malicious activities.
#' The function can be used to screen zip files or individual files for these potentially dangerous file types.
#'
#' @param files A character vector of file paths. These can be paths to zip files or individual files.
#'
#' @return A logical value indicating if any of the files in the input have a malicious file extension. Returns `TRUE` if any malicious file is found, otherwise `FALSE`.
#'
#' @importFrom tools file_ext
#'
#' @examples
#' \dontrun{
#'   check_for_malicious_files("path'(s)'/to/your/files")
#'   check_for_malicious_files(utils::unzip("path/to/your/file.zip", list = TRUE)$Name)
#' }
#'
#' @export
check_for_malicious_files <- function(files) {
    # Define the malicious extensions
    malicious_extensions <- c("_exe", "a6p", "ac", "acr", "action", "air", "apk", "app",
                              "applescript", "awk", "bas", "bat", "bin", "cgi", "chm",
                              "cmd", "com", "cpl", "crt", "csh", "dek", "dld", "dll",
                              "dmg", "drv", "ds", "ebm", "elf", "emf", "esh", "exe",
                              "ezs", "fky", "frs", "fxp", "gadget", "gpe", "gpu", "hlp",
                              "hms", "hta", "icd", "iim", "inf", "ins", "inx", "ipa",
                              "ipf", "isp", "isu", "jar", "js", "jse", "jsp", "jsx",
                              "kix", "ksh", "lib", "lnk", "mcr", "mel", "mem", "mpkg",
                              "mpx", "mrc", "ms", "msc", "msi", "msp", "mst", "mxe",
                              "obs", "ocx", "pas", "pcd", "pex", "pif", "pkg", "pl",
                              "plsc", "pm", "prc", "prg", "pvd", "pwc", "py", "pyc",
                              "pyo", "qpx", "rbx", "reg", "rgs", "rox", "rpj", "scar",
                              "scpt", "scr", "script", "sct", "seed", "sh", "shb",
                              "shs", "spr", "sys", "thm", "tlb", "tms", "u3p", "udf",
                              "url", "vb", "vbe", "vbs", "vbscript", "vdo", "vxd",
                              "wcm", "widget", "wmf", "workflow", "wpk", "ws", "wsc",
                              "wsf", "wsh", "xap", "xqt", "zlq")
    
    file_extensions <- tools::file_ext(files)
    if (any(file_extensions %in% malicious_extensions)) {
        return(TRUE)
    }
    
    return(FALSE)
}

#' @title Query a MongoDB document by an ObjectID
#'
#' @description This function queries a mongodb database using its API to retrieve a document by its ObjectID. Use the MongoDB Atlas Data API to create an API key.
#' 
#' @param collection The name of the collection in the MongoDB database.
#' @param database The name of the MongoDB database.
#' @param dataSource The data source in MongoDB.
#' @param apiKey The API key for accessing the MongoDB API.
#' @param objectId The object ID of the document to query.
#'
#' @return The queried document.
#'
#' @examples
#' \dontrun{
#' apiKey <- 'your_mongodb_api_key'
#' collection <- 'your_mongodb_collection'
#' database <- 'your_database'
#' dataSource <- 'your_dataSource'
#' objectId <- 'example_object_id'
#' query_document_by_object_id(apiKey, collection, database, dataSource, objectId)
#' }
#' 
#' @import httr
#' @import jsonlite
#' @export
query_document_by_object_id <- function(apiKey, collection, database, dataSource, objectId) {
    # Construct the URL for the find endpoint
    url <- "https://us-west-2.aws.data.mongodb-api.com/app/data-crrct/endpoint/data/v1/action/find"
    
    # Set up the query payload
    body <- list(
        dataSource = dataSource,
        database = database,
        collection = collection,
        filter = list(
            "_id" = list(
                "$oid" = objectId
                )
            )
        )
    
    # Make the POST request
    response <- httr::POST(
        url,
        body = toJSON(body, auto_unbox = TRUE),
        add_headers(`Content-Type` = "application/json", `api-key` = apiKey),
        encode = "json"
    )
    
    # Check and return the response
    if (response$status_code == 200) {
        return(httr::content(response, "parsed"))
    } else {
        stop("Failed to query MongoDB Atlas Data API: ", response$status_code)
    }
    }

#' @title Run any of the apps
#'
#' @description This wrapper function starts the user interface of your app choice.
#'
#' @details
#' After running this function the Validator, Microplastic Image Explorer, or Data Visualization GUI should open in a separate
#' window or in your computer browser.
#'
#' @param path to store the downloaded app files; defaults to \code{"system"}
#' pointing to \code{system.file(package = "One4All")}.
#' @param log logical; enables/disables logging to \code{\link[base]{tempdir}()}
#' @param ref git reference; could be a commit, tag, or branch name. Defaults to
#' "main". Only change this in case of errors.
#' @param test_mode logical; for internal testing only.
#' @param app your app choice
#' @param \dots arguments passed to \code{\link[shiny]{runApp}()}.
#'
#' @return
#' This function normally does not return any value, see
#' \code{\link[shiny]{runGitHub}()}.
#'
#' @examples
#' \dontrun{
#' run_app(app = "validator")
#' }
#'
#' @author
#' Hannah Sherrod, Nick Leong, Hannah Hapich, Fabian Gomez, Win Cowger
#'
#' @seealso
#' \code{\link[shiny]{runGitHub}()}
#'
#' @importFrom shiny runGitHub shinyOptions
#' @importFrom utils installed.packages
#' @export
run_app <- function(path = "system", log = TRUE, ref = "main", test_mode = FALSE, app = "validator", ...) {
    pkg <- c("shiny", "dplyr", "DT", "shinythemes", "shinyWidgets", "validate", "digest", "data.table",
             "bs4Dash", "ckanr", "purrr", "shinyjs", "sentimentr", "listviewer", "RCurl", "readxl", "stringr",
             "openxlsx", "config", "aws.s3", "One4All", "mongolite", "leaflet", "plotly", "readr", "tidyverse", "tidygeocoder", "sf",
             "mapview", "mapdata", "data.table", "ggdist", "ggthemes", "ggplot2", "rlang", "PupillometryR", "gridExtra", "networkD3", "tidyr",
             "janitor", "jsonlite", "httr", "googlesheets4", "curl")
    
    miss <- pkg[!(pkg %in% installed.packages()[ , "Package"])]
    
    if(length(miss)) stop("run_app() requires the following packages: ",
                          paste(paste0("'", miss, "'"), collapse = ", "),
                          call. = FALSE)
    
    app_dirs <- c("validator" = "inst/apps/validator",
                  "data_visualization" = "inst/apps/data_visualization",
                  "microplastic_image_explorer" = "inst/apps/microplastic_image_explorer")
    
    app_dir <- app_dirs[[app]]
    if(is.null(app_dir)) stop("Invalid app specified. Available apps: validator, data_visualization, microplastic_image_explorer")
    
    dd <- ifelse(path == "system",
                 system.file(package = "One4All"),
                 path)
    
    Sys.setenv(R_CONFIG_ACTIVE = "run_app")
    
    options(shiny.logfile = log)
    if(!test_mode)
        runGitHub("One4All", "Moore-Institute-4-Plastic-Pollution-Res", ref = ref, subdir = app_dir)
}
