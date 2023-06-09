% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/global.R
\name{check_other_hyperlinks}
\alias{check_other_hyperlinks}
\title{Check and format non-image hyperlinks}
\usage{
check_other_hyperlinks(x)
}
\arguments{
\item{x}{A character string to check for non-image hyperlinks.}
}
\value{
A character string with the HTML anchor tag if a non-image hyperlink is found, otherwise the input string.
}
\description{
This function checks if the input string contains a non-image hyperlink and formats it as an HTML anchor tag.
}
\examples{
check_other_hyperlinks("https://example.com/page")
check_other_hyperlinks("https://example.com/image.png")
check_other_hyperlinks("https://example.com/image.jpg")
}
