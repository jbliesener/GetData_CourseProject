# Before running this script, the following libraries must be installed
listOfPackages <- c("LaF", "stringr", "dplyr")

# find packages that need to be installed
newPackages <- listOfPackages[!(listOfPackages %in% installed.packages()[,"Package"])]
if (length(newPackages) != 0) install.packages(newPackages)

# load libraries from list
lapply(listOfPackages,function(x){library(x,character.only=T)})

######################################################################################
# Part 1: (Reads and) merges the training and test sets to create one data set
#

# Reading the data is not a straightforward task here, as the data is fixed width.
# Although the read.fwf function was designed to process this kind of data, it
# performs very weak and requires lots of memory.
# Therefore we use the LaF package, which however requires ffbase to convert
# the data read into a dataframe
read_data_frame <- function (filename, colCount) {
        # open the data file
        dataFile <- laf_open_fwf(filename, 
                                 column_types=rep("double",colCount),
                                 column_widths=rep(16,colCount))
        
        # return a dataframe from dataFile
        dataFile[]
}

# use the function to read the two data sets. Each one has 561 variables 
testData  <- read_data_frame("test/X_test.txt",   561)
trainData <- read_data_frame("train/X_train.txt", 561)

# we can read the activity and subject with read.csv, as it is only a single field per line
testActivity  <- read.csv("test/y_test.txt",   header=FALSE)
trainActivity <- read.csv("train/y_train.txt", header=FALSE)

testSubject   <- read.csv("test/subject_test.txt",   header=FALSE)
trainSubject  <- read.csv("train/subject_train.txt", header=FALSE)

# add type of data, activity and subject as the first columns in both data sets
testData  <- cbind("test",  testActivity,  testSubject,  testData )
trainData <- cbind("train", trainActivity, trainSubject, trainData)

# rename first three columns
names(testData )[1:3] <- c("dataset","activity","subject")
names(trainData)[1:3] <- c("dataset","activity","subject")

# join datasets
dataset <- rbind(testData,trainData)

###############################################################################
# Part 2: Extracts only the measurements on the mean and standard deviation 
#         for each measurement

# In order to identify the required columns, we read the column numbers and names 
# ("labels") from the data dictionary
dict <- read.csv("features.txt", sep=" ", header=FALSE)
names(dict) <- c("columnNumber","columnName")

# Find all lines that have "mean()" or "std()" in its label text.
# Those are the COLUMNS that we want to retain in "dataset"
# First we create a boolean vector that is TRUE only for the lines that are to be retained
retainColumns <- 
        str_detect(dict$columnName,".*mean\\(\\).*") | 
        str_detect(dict$columnName,".*std\\(\\).*" )

# Now we create a new data frame that contains only those lines
selectedColumns <- dict[retainColumns,]

# Remember that the LINES in "selectedColumns" represent the COLUMNS in "dataset".
# Each of those lines in "selectedColumns" has in its first column the NUMBER of 
# the column that it reprsents in "dataset". However, as we've added three additional 
# columns (and might add more in the future), it is safer to use the original column 
# names "V1", "V2", ... 
# So let's construct a chr vector that represents the NAMES of the columns that are to
# be retained in "dataset"
selectedColumnNames <- paste("V", selectedColumns$columnNumber, sep="")

# Finally, create a new data frame with only the selected columns, plus the first three
# that we've added
processedDataset <- dataset[,c(1:3, which(colnames(dataset) %in% selectedColumnNames))]

# Wasn't that nice?

###############################################################################
# Part 3: Uses descriptive activity names to name the activities in the data set 
#

# We read the activity names from file
activities <- read.csv("activity_labels.txt", header=FALSE, sep=" ")
names(activities) <- c("activityNumber","activityName")

# and we transform the "activity" column into a factor variable
processedDataset$activity <- factor(processedDataset$activity,
                                    levels=activities$activityNumber,
                                    labels=activities$activityName)

# That's all!

###############################################################################
# Part 4: Appropriately labels the data set with descriptive variable names 
#

# We still have the column mapping list. So we just clean up and use the names 
# from this list as new column names

# Extract column numbers
columnNumbers <- which(colnames(processedDataset) %in% selectedColumnNames)

# get new column names, get rid of the parentheses and transform 
# other invalid characters into dots
newColumnNames <- make.names(str_replace_all(selectedColumns$columnName,"\\(\\)",""))

# assign new column names
names(processedDataset)[columnNumbers] <- newColumnNames


###############################################################################
# Part 5: From the data set in step 4, creates a second, independent tidy data 
# set with the average of each variable for each activity and each subject.
#

# This is where dplyr comes in and provides the very handy summarise_each function
averagedDataset <- processedDataset %>% 
        group_by(subject,activity) %>% 
        summarise_each(funs(mean))

# One line does it all! But let's prepend a "avg." to the column names, so that we know
# that these are averaged data
colnums <- 4:ncol(averagedDataset)
newNames <- paste("avg.",names(averagedDataset)[colnums],sep="")
names(averagedDataset)[colnums] <- newNames

