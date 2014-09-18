---
title: "Getting and Cleaning Data Course Project"
author: "Jorg Bliesener"
date: "Thursday, September 18, 2014"
output: html_document
---

This course project retrieves, cleans and processes data obtained from a smartphone acceleration sensor during various activities. This data was collected in order to detect a certain type of activity from the movements of the cellphone owner.

The purpose of the course project is to demonstrate the ability to collect, work with, and clean a data set. The goal is to prepare tidy data that can be used for later analysis. Details here: <https://class.coursera.org/getdata-007/human_grading/view/courses/972585/assessments/3> (requires login and enrollment in the "Getting and Cleaning Data" course)

To achieve the goal, a single script called "run_analysis.R" should be created which performs the following tasks:

1. Merges the training and the test sets to create one data set.
2. Extracts only the measurements on the mean and standard deviation for each measurement. 
3. Uses descriptive activity names to name the activities in the data set
4. Appropriately labels the data set with descriptive variable names. 
5. From the data set in step 4, creates a second, independent tidy data set with the average of each variable for each activity and each subject.

The script is provided in the same github repository as this markdown file and contains comments on almost every statement executed. This markdown file provides additional explanations on the various steps.

### Loading required libraries ###
The script requires the following libraries:

- ```LaF```: Large ASCII Files (used to read the source data)
- ```stringr```: regular expression search (used to process column names)
- ```dplyr```: data manipulation (used to group and calculate column means)

Not all of these packages may be installed on the users' computer, so the script tries to download and install the missing ones. I therefore use the ```installed.packages()``` function and the ```character.only``` parameter for the ```library()``` function, together with ```lapply()```.

### Reading and merging the data ###
Looking at the source data, it gives us the first impression that we can use read.csv. However, this doesn't work as expected, as we would need to use the "space" character as column separator and this character also appears in front of positive numbers. 

The solution is to use fixed width columns. R provides the ```read.fwf()``` function to read fixed width data, however its performance and memory requirement renders it unfeasible for the provided data set.

Therefore, the data is read with the ```laf_open_fwf()``` function from the ```LaF``` package. This function requires us to specify the width and type of all data columns and returns an object of type ```laf```. A user-defined function is provided with the filename and the number of columns in the data set (541, as we know from the data dictionary), generates the required parameters for ```laf_open_fwf()``` and returns a data frame that contains the retrieved dataset.

The columns that represent activity and subject must be retrieved from different files that contain only a single column and therefore can be read with ```read.csv()```. I then merge the columns together with ```cbind()```, adding another variable that represents the type of data set ("train" or "test"). Finally, I rename the first three columns in each dataset so that they describe the actual content:

- ```dataset```: The type of dataset ("train" or "test"). This is a factor variable with two levels.
- ```activity```: The activity number retrieved from the "Y_..." files.
- ```subject```: The subject number retrieved from the "Subject_..." files.

When both datasets (```trainData``` and ```testdata```) have the same structure, I can concatenate them with a simple ```rbind()``` call. This gives me the ```dataset``` data frame with 10299 observations (2947 from the "test" dataset, 7352 from the "train" dataset) of 564 variables (561 from the raw data file plus the 3 added columns).

### Extracting mean and standard deviation values ###
While I could do this with a direct approach, specifying the numbers of the columns in ```dataset``` that hold the required values, it would not just be a very boring task, but also prone to errors.

Therefore, I decided to make use of the dictionary data in "features.txt":

```
1 tBodyAcc-mean()-X
2 tBodyAcc-mean()-Y
3 tBodyAcc-mean()-Z
4 tBodyAcc-std()-X
5 tBodyAcc-std()-Y
6 tBodyAcc-std()-Z
...
```

Each line contains the column number and a short description of its content. I read this dictionary into a separate data frame ```dict``` that then represents the metadata for ```dataset```: Each line of ```dict``` describes a column of ```dataset```. Note that these columns in ```dataset``` are named ```V1```, ```V2``` and so on.

The task is to maintain only the mean and standard deviation columns from the data set. The column names of these have a specific pattern: They all contain either ```mean()``` or ```std()```. Note hoewever, that there are columns that contain ```meanFreq()```. We don't want these, so we need to filter for ```mean()```, including the parantheses.

This is what ```str_detect(dict$columnName, <pattern>)``` does. It returns a boolean vector in which each element tells us if the associated element in ```dict$columnName``` fulfills a specific pattern. So, I produce a boolean vector ```retainColumns``` that tells us which columns we want to retain in ```dataset```. Applying this vector to ```dict```, it gives me a data frame ```selectedColumns``` with the number and a description of the columns that I want to retain in data set. 

Well, not quite, as I've added three columns when I merged the data. But the column **names** for the original data are still ```V1```, ```V2```, ```V3``` and so on. So, I simply transform the column number in ```selectedColumns``` into a chr vector and prepend a "V". The resulting vector ```selectedColumnNames``` gives me the **names** of the columns to retain in ```dataset```.

```which(colnames(dataset) %in% selectedColumnNames``` transforms this into a vector of column numbers, to which I add the first three columns. I then simply subset those columns into a new data frame ```processedDataset``` that now holds the same 10299 observations, however only in 69 variables that represent mean and standard deviation.

Conclusion: The required columns were identified by reading and automatically processing the data dictionary.

### Use descriptive activity names ###
This is actually easier than it seems. I can read the activity names from "activity_labels.txt", a file that only contains this data:

```
1 WALKING
2 WALKING_UPSTAIRS
3 WALKING_DOWNSTAIRS
4 SITTING
5 STANDING
6 LAYING
```

I read this into a data frame activities with ```read.csv("activity_labels.txt", header=FALSE, sep=" ")```. Then I transform the ```activity``` column in dataset into a factor variable, using the levels and labels from ```activity```. One function call does it all:

```
processedDataset$activity <- factor(processedDataset$activity,
                                    levels=activities$activityNumber,
                                    labels=activities$activityName)
```

### Label data set columns ###
Again, I can use the data dictionary retrieved earlier. I identify the column numbers in the new dataset ```processedDataset```. As new column names, I simply use the labels retrieved from the dictionary, however I apply some processing: I eliminate all parentheses "()" and transform the remaining invalid characters into dots using the ```make.names()``` function. 

### Create a second data set that holds the average of each variable for each activity and each subject ###
This is where dplyr comes in. I create a simple processing chain, grouping by activity and subject and then applying the ```summarise_each()``` function, which calculates the mean for all remaining columns. A one-liner:

```
averagedDataset <- processedDataset %>% 
        group_by(subject,activity) %>% 
        summarise_each(funs(mean))
```

However, I would like to emphasize that the resulting data frame ```averagedDataset``` now actually holds the averages of the values, so I decided to rename the columns, prepending an ```avg.``` to each column name except for the first three.