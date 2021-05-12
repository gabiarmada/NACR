# nacr_drop 

The purpose of the nacr_drop function is to retrieve .ncf files containing NACR data from the user's Dropbox account, and return a dataframe of FIPS, longitude, latitude, pm2.5, and .ncf file name information based on which rows of data the user wants to keep. <br/> <br/>

**First, let's go over the parameters of the nacr_drop() function...** <br/> 
This function must accept 6 parameters: 
* fileread: The file name of the .ncf file containing pm2.5 measurements. 
* latlonfile: The file name of the .ncf file containing latitude and longitude values.

> Note: fileread and latlonfile must be located in the user's Dropbox, in a folder titled *NACR*.

* whkeep1: Which rows of the .ncf files to keep (based on lat/long organization for efficiency). 
* fipsdat1: FIPS information based on the rows and columns of the lat/long data. Fipsdat1 should be a dataframe containing FIPS, and row/column information. 
* cols1: column information based on the lat/long data.
* rows1: row information based on the lat/long data. 

<br/> <br/> 

**Now, let's step through what the nacr_drop() function does...**<br/> <br/> 
The first lines of the function uses **drop_download()** from the *rdrop2* package to download the .ncf files from the user's Dropbox to their local disk, overwriting the file if it already exists in the user's local path: 
```
 # download files from dropbox
drop_download(path = file.path("NACR", fileread),
              local_path = file.path(here(), fileread),
              overwrite = T, progress = F, verbose = F)
drop_download(path = file.path("NACR", latlonfile),
              local_path = file.path(here(), latlonfile),
              overwrite = T, progress = F, verbose = F)
```
<br/> <br/> 
Next, we must open the .ncf files using **nc_open()** from the *ncdf4* package, and assign the resulting lists to the variable names **ncfile** and **latlon**: 
```
# read files
ncfile <- nc_open(file.path(here(), fileread))
latlon <- nc_open(file.path(here(), latlonfile
```
<br/> <br/> 
After reading in the .ncf files, the function then extracts the pm2.5 measurements and the latitude/longitude values from the previously defined lists (*ncfile* and *latlon*). The following lines of the nacr_drop() function uses **ncvar_get()** from the *ncdf4* package to read the data from the existing ncdf files, and assigns the matrix output to the variable names **pm1**, **lat1**, and **lon1**: 
```
# get PM, lat, lon 
pm1 <- ncvar_get(ncfile, "PM25_TOT") 
lat1 <- ncvar_get(latlon, "LAT")
lon1 <- ncvar_get(latlon, "LON")
```
<br/> <br/> 
Next, the function creates a dataframe of the columns: *pm*, *lat*, *lon*, *col*, and *row*, which are based on the previously defined matrices. **cols1**, defined by the user, contains the column information from the lat/long data. Similarly, **rows1** contains the row information from the lat/long data. The resulting **pm2** dataframe, is a dataframe of pm2.5 measurements, lat/long values, and the row/col identifiers: 
```
# find rows and columns
pm2 <- data.frame(pm = as.vector(pm1),
                  lat = as.vector(lat1), 
                  lon = as.vector(lon1),
                  col = as.vector(cols1),
                  row = as.vector(rows1))
```
<br/> <br/> 
Next, the function subsets the newly created **pm2** dataframe to only include the desired grids, which are define by the user in the **whkeep1** parameter. 
```
# keep only grids desired
pm2 <- pm2[whkeep1, ]
```
<br/> <br/> 
Once the **pm2** dataframe has been subsetted to only include the rows and columns of interest, the nacr_drop() function then uses **left_join()** from the *dplyr* package to join the **pm2** dataframe with the **fipsdat1** datframe defined by the user. The following lines of the function then remove the columns containing row and column identifiers from the **pm2** dataframe, group the dataframe by **FIPS**, summarize each FIPS code by the mean pm2.5 measurement (removing NA values), and finally, mutate a column titled **name** that contains the .ncf filename for the pm2.5 measurements:
```
# get fips for averaging
pm2 <- left_join(pm2, fipsdat1, by = c("row", "col")) %>%
       select(-col, -row) %>%
       group_by(FIPS) %>%
       summarize(pm = mean(pm, na.rm = T)) %>%
       mutate(name = fileread)
```
<br/> <br/> 
Now, we want to include latitude and longitude in our **pm2** output. This function uses the **geoCounty** built-in R dataset from the *housingData* package to extract the latitude and longitude centroids for each FIPS code location. The following lines of the function load in the **geoCounty** dataset, filter **geoCounty** based on the FIPS code locations contained in the **pm2** dataframe, rename the **geoCounty** *fips* column to be compatible with the **pm2** *FIPS* column, and select only the columns of interest from the **geoCounty** dataset (*FIPS*, *lon*, and *lat*): 
```
# include lat/ lon centroid in output
data("geoCounty")
geoCounty <- filter(geoCounty, fips %in% pm2$FIPS) %>%
             rename(FIPS = fips)%>%
             select(FIPS, lon, lat)
```
<br/> <br/>
Finally, we merge the **geoCounty** and **pm2** dataframes by the *FIPS* column and assign the output to the **pm2** variable. The resulting **pm2** dataframe is a dataframe of 5 columns (*FIPS*, *lon*, *lat*, *pm*, and *name*) containing the latitude/longitude centroid, and the average pm2.5 measurement collected from each FIPS code location:  
```
pm2 <- merge(geoCounty, pm2, by = "FIPS")
```
<br/> <br/>
**Some cleaning up...** 
<br/> <br/>
Finally, the following lines remove the .ncf files from the user's local disk, closes the .ncf files, and returns the **pm2** dataframe: 
> Note: it is important to always close .ncf files when you are done with them. Otherwise, you are risking data loss. 
<br/>

```
# remove files locally
rm1 <- paste0("rm ", fileread)
rm2 <- paste0("rm ", latlonfile)
system(rm1)
system(rm2)
    
# close files 
nc_close(ncfile)
nc_close(latlon)
    
# return
pm2
}
```

