#Create capture history in camtrapR from eMammal .csv files
#Brent Pease (@BrentPease1)



ols.sys.timezone <- Sys.timezone()
Sys.setenv(TZ = 'GMT')

#install.packages("data.table")
#install.packages("camtrapR")
#devtools::install_github("krlmlr/here") #a package 'here'. Be sure to get this package. This let's us easily specify the outDir for our final Capture History without the in-script Directory being specific to an individual's machine. 
library(data.table)
library(camtrapR)
library(here)

#read in dataset
cameras <- fread("example_data.csv")
names(cameras) <- gsub(" ",".",names(cameras))  #remove spaces from column headers and replace with '.'

#####Work flow####
#1. Create 'camera station table' (This is an object (or file) describing the name, location, and date/time of all camera traps)
#2. Using the camera station table, create a 'camera operation matrix' (this is an object (or file) describing the data/time a camera was operating and the total number of days camera was running)
#3. Format initial dataset object (in this case, cameras) to be a 'record table' (This is an object (or file) containing all unique capture events, their location, and date/time)
#4. Create capture history (i.e., detection history) of specified species using camtrapR::detectionHistory
##################

#1.TO create camera station table, first find start and end camera dates 

#replace 'T' in x.Time with " " (a space)
cameras$Begin.Time <- gsub("T"," ",cameras$Begin.Time)
cameras$End.Time <- gsub("T"," ",cameras$End.Time)

# format with as.POSIXct()
cameras$Begin.Time <- as.POSIXct(cameras$Begin.Time, format = "%Y-%m-%d %H:%M:%S") 
cameras$End.Time <- as.POSIXct(cameras$End.Time, format = "%Y-%m-%d %H:%M:%S")
str(cameras$Begin.Time)
str(cameras$End.Time)

z <- cameras[,.(Deploy.ID,Begin.Time),by=Deploy.ID] #subset cameras to have only two columns and grouped by Deploy.ID #Note: '.()' is data.table's equivalent to base R's list()

start.dates <- z[,min(Begin.Time, na.rm=T),by=Deploy.ID] #find start date for each camera
colnames(start.dates) <- c("Deploy.ID", "Start.Date")

end.dates <- z[,max(Begin.Time, na.rm=T),by=Deploy.ID] #find end date for each camera
colnames(end.dates) <- c("Deploy.ID", "End.Date")

# remove duplicates (sometimes there is 2 or more events with same first or last Begin.Time)  
start.dates <- start.dates[!duplicated(start.dates$Deploy.ID),]
end.dates <- end.dates[!duplicated(end.dates$Deploy.ID),]


### merge with cameras
cameras <- merge(cameras, start.dates, by = "Deploy.ID", all.x = T, suffixes = '')
cameras <- merge(cameras, end.dates, by = "Deploy.ID", all.x = T, suffixes = '')


#just need the following rows for camtrapR::camera trap station information (CT station info):
#Station (deploy.id), location (lat/lon), setup.date, retrieval.date, problem_from1, problem_to1
#problem_from and problem_to are columns to let camtrapR know of a camera malfunction

y <- cameras[, .(Deploy.ID,Actual.Lon,Actual.Lat,Start.Date,End.Date)]
names(y) <- c("Station","Longitude","Latitude","Setup_date","Retrieval_date") #clean up the names

y <- y[,`:=`(Problem1_from="",Problem1_to="")] #add empty columns for problematic cameras

y$Setup_date <- substr(y$Setup_date,1,10) #make setup_date and retrieval_date column only contain date and not time
y$Retrieval_date <- substr(y$Retrieval_date,1,10) 

x <- y[!duplicated(y$Station)] #return only one row of each Station
print(x)  #make sure this looks good
x <- as.data.frame(x) #camtrapR needs data.frame. data.tables are data.frames, but...


# 2. create camera operation matrix
# for an example of a CTtable, load data(camtraps) from camtrapR package then View(camtraps)

camop <- cameraOperation(CTtable      = x,                           #this is our CT station information  
                                    stationCol   = "Station",        #which column contains station information 
                                    setupCol     = "Setup_date",     #which column contains setup_date info
                                    retrievalCol = "Retrieval_date", #Ditto 
                                    hasProblems  = FALSE,            #were there camera malfunctions?
                                    dateFormat   = "%Y-%m-%d"
)

#3. We just now need to format our initial .csv (in this case, 'cameras') to be a 'record table'
#at minimum, we need a column for StationID, SpeciesID, and date/time. 
#for an example, load data(recordTableSample) from camtrapR package then View(recordTableSample)

w <- cameras[,.(Deploy.ID,Common.Name,Begin.Time)] #data.frame with 3 columns 
colnames(w) <- c("Station","Species","DateTimeOriginal") #define column names
w <- as.data.frame(w) #make sure this looks good 

#4. compute detection history for a species
DetHist1 <- detectionHistory(recordTable         = w,                     #a list of all capture events with their location and date/time stamp
                             camOp                = camop,                #our camera trap operation matrix
                             stationCol           = "Station",            
                             speciesCol           = "Species",
                             recordDateTimeCol    = "DateTimeOriginal",
                             recordDateTimeFormat = "%Y-%m-%d %H:%M:%S",
                             species              = "White-tailed Deer", #which species to create detection history for, from the species in 'w' 
                             occasionLength       = 1,                   #how many days should be the occasion length?
                             day1                 = "station",           #WHen should occassions begin: station setup date("station"), first day of survey("survey"), or a specified date (e.g., "2015-12-25")?
                             datesAsOccasionNames = FALSE,               #only applies if day1="survey"
                             includeEffort        = FALSE,               #compute trapping effort(number of active camera trap days per station and occasion)?
                             timeZone             = "GMT",
                             writecsv = TRUE,
                             outDir = here("Capture_Histories"))         #here specifies the base directory and then "Capture_Histories" specifies folder within base directory
