% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dependency.R
\name{spark_dependencies_from_extension}
\alias{spark_dependencies}
\alias{spark_dependencies_from_extension}
\alias{spark_dependencies_from_extensions}
\title{Get the spark dependencies for extension packages}
\usage{
spark_dependencies_from_extension(extension)

spark_dependencies_from_extensions(extensions)
}
\arguments{
\item{extension}{Name of extension package}

\item{extensions}{Names of extension packages.}
}
\value{
List of objects of type \code{spark_dependency}.
}
\description{
Call the \code{spark_dependencies} function of the specified
package to extract it's dependencies.
}
\keyword{internal}

