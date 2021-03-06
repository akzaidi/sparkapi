Spark API Interface
================

Introduction
------------

The [SparkR](https://github.com/apache/spark/tree/master/R) package introduces a custom RPC method that allows calling arbitrary Java/Scala code within the Spark shell process from R. The SparkR package's higher level functions are in turn built upon this RPC layer.

SparkR provides one front-end from R to Spark, however the development of other front-end packages is desirable (e.g. a front-end that package that is compatible with [dplyr](https://github.com/hadley/dplyr), which SparkR is not due to it's masking of many of dplyr's functions).

The **sparkapi** package factors out the core RPC protocol from SparkR, with the goal of making the core types used by Spark front-end packages inter-operable. This should in turn enable the creation of extension packages that work well with all front-end packages.

Extension Packages
------------------

Spark extension packages are add-on R packages that implement R interfaces for Spark services.

Extension packages consist of R functions which don't themselves connect directly to Spark, but rather depend on a connection already made by SparkR or another front-end package.

Front-end packages also typically have facilities for accessing, filtering, and manipulating Spark data frames. Extension packages can also leverage these capabilities by accepting a `spark_dataframe` object created by a front-end package as an argument.

The following sections describe the core mechanism uses to invoke the Spark API from within R. Following that, some simple examples of R functions that might be included in an extension package are provided.

Core Types
----------

The sparkapi package defines 3 classes for representing the fundamental types of the R to Java bridge:

| Function          | Description                                      |
|-------------------|--------------------------------------------------|
| spark\_connection | Connection between R and the Spark shell process |
| spark\_jobj       | Instance of a remote Spark object                |
| spark\_dataframe  | Instance of a remote Spark DataFrame object      |

S3 methods are defined for each of these classes so they can be easily converted to / from objects that contain or wrap them. Note that for any given `spark_jobj` it's possible to discover the underlying `spark_connection`.

Calling Spark from R
--------------------

There are several functions available for calling the methods of Java objects and static methods of Java classes:

| Function       | Description                                   |
|----------------|-----------------------------------------------|
| invoke         | Call a method on an object                    |
| invoke\_new    | Create a new object by invoking a constructor |
| invoke\_static | Call a static method on an object             |

For example, to create a new instance of the `java.math.BigInteger` class and then call the `longValue()` method on it you would use code like this:

``` r
billionBigInteger <- invoke_new(sc, "java.math.BigInteger", "1000000000")
billion <- invoke(billionBigInteger, "longValue")
```

Note the `sc` argument: that's the `spark_connection` object which is provided by the front-end package (e.g. SparkR).

The previous example can be re-written to be more compact and clear using [magrittr](https://cran.r-project.org/web/packages/magrittr/vignettes/magrittr.html) pipes:

``` r
billion <- sc %>% 
  invoke_new("java.math.BigInteger", "1000000000") %>%
    invoke("longValue")
```

This syntax is similar to the method-chaining syntax often used with Scala code so is generally preferred.

Calling a static method of a class is also straightforward. For example, to call the `Math::hypot()` static function you would use this code:

``` r
hypot <- sc %>% 
  invoke_static("java.lang.Math", "hypot", 10, 20) 
```

Wrapper Functions
-----------------

Creating an extension typically consists of writing R wrapper functions for a set of Spark services. In this section we'll describe the typical form of these functions as well as how to handle special types like Spark DataFrames.

Here's an example of a wrapper function for the the text file line counting function available from the SparkContext object:

``` r
count_lines <- function(sc, path) {
  spark_context(sc) %>% 
    invoke("textFile", path, as.integer(1)) %>% 
      invoke("count")
}
```

The `count_lines` function takes a `spark_connection` (`sc`) argument which enables it to obtain a reference to the `SparkContext` object.

The following functions are useful for implementing wrapper functions of various kinds:

| Function          | Description                                             |
|-------------------|---------------------------------------------------------|
| spark\_connection | Get the Spark connection associated with an object (S3) |
| spark\_jobj       | Get the Spark jobj associated with an object (S3)       |
| spark\_dataframe  | Get the Spark DataFrame associated with an object (S3)  |
| spark\_context    | Get the SparkContext for a `spark_connection`           |
| hive\_context     | Get the HiveContext for a `spark_connection`            |

The use of these functions is illustrated in this simple example:

``` r
analyze <- function(x, features) {
  
  # normalize whatever we were passed (e.g. a dplyr tbl) into a DataFrame
  df <- spark_dataframe(x)
  
  # get the underlying connection so we can create new objects
  sc <- spark_connection(df)
  
  # create an object to do the analysis and call its `analyze` and `summary`
  # methods (note that the df and features are passed to the analyze function)
  summary <- sc %>%  
    invoke_new("com.example.tools.Analyzer") %>% 
      invoke("analyze", df, features) %>% 
      invoke("summary")

  # return the results
  summary
}
```

The first argument is an object that can be accessed using the Spark DataFrame API (this might be an actual reference to a DataFrame or could rather be a dplyr `tbl` which has a DataFrame reference inside it).

After using the `spark_dataframe` function to normalize the reference, we extract the underlying Spark connection associated with the data frame using the `spark_connection` function. Finally, we create a new `Analyzer` object, call it's `analyze` method with the DataFrame and list of features, and then call the `summary` method on the results of the analysis.

Accepting a `spark_jobj` or `spark_dataframe` as the first argument of a function makes it very easy to incorporate into magrittr pipelines so this pattern is highly recommended when possible.

Dependencies
------------

When creating R packages which implement interfaces to Spark you may need to include additional dependencies. Your dependencies might be a set of [Spark Packages](https://spark-packages.org/) or might be a custom JAR file. In either case, you'll need a way to specify that these dependencies be included during the initialization of a Spark session. A Spark dependency is defined using the `spark_dependency` function:

<table>
<colgroup>
<col width="38%" />
<col width="61%" />
</colgroup>
<thead>
<tr class="header">
<th>Function</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>spark_dependency</td>
<td>Define a Spark dependency consisting of JAR files and Spark packages</td>
</tr>
</tbody>
</table>

Your extension package can specify it's dependencies by implementing a function named `spark_dependencies` within the package (this function should *not* be publicly exported). For example, let's say you were creating an extension package named **sparkds** that needs to include a custom JAR as well as the Redshift and Apache Avro packages:

``` r
spark_dependencies <- function(...) {
  spark_dependency(
    jars = system.file("java/sparkds.jar", package = "sparkds"),
    packages = c("com.databricks:spark-redshift_2.10:0.6.0",
                 "com.databricks:spark-avro_2.10:2.0.1")
  )
}
```

The `...` argument is unused but nevertheless should be included to ensure compatibility if new arguments are added to `spark_dependencies` in the future.

When users connect to a Spark cluster and want to use your extension package within their session they simply include the **sparkds** package in a list of extensions passed to e.g. `SparkR.init`:

``` r
library(SparkR)
sc <- sparkR.init(master = "local", extensions = c("sparkds"))
```
