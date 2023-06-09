% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/global.R
\name{test_profanity}
\alias{test_profanity}
\title{Test for profanity in a string}
\usage{
test_profanity(x)
}
\arguments{
\item{x}{A character string to check for profanity.}
}
\value{
A logical value indicating whether the input string contains no profane words.
}
\description{
This function checks if the input string contains any profane words.
}
\examples{
test_profanity("This is a clean sentence.")
test_profanity("This sentence contains a badword.")
}
