#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#
# Copyright (c) 2016, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# 
# This script is designed to be run that will query the JSS and download a csv of an 
# Advanced Computer  search, it is designed to be able to be run from the JSS with script
# variables or have the variables hardcoded, and save a CSV onto that users Desktop 
#
#
# Written by: Daniel MacLaughlin | Professional Services Engineer | JAMF Software
# with thanks to Duncan McCracken and Josh Roskos
#
# Created On: May 25th, 2016
# 
# version 1.0
#
# Version 1.1 by Daniel MacLaughlin 21st July 2016
# added proper close function to fix if report count is higher than 20
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# VARIABLES
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# jss info
JSSURL="https://jss.mycompany.com:8443" #Please be sure to include the port if required
JSSUSER="apiusername"
JSSPASS="apipassword"
JSSSEARCH="ReportName" # Case Sensitive please include %20 if the Report name has spaces ie "Not Encrypted" should be "Not%20Encrypted"


#Things to be aware of....
#For your display fields always include the "Computer Name"
#May cause errors if your machine names have a " in the name ie My 13" macbook air
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# START APPLICATION
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

#Lets create a working directory for our tmp files

#This Directory is for the Main Report
DIRECTORY="/tmp/JSS_Report"
if [ ! -d "$DIRECTORY" ]; then
  mkdir /tmp/JSS_Report
fi

#This Direcotry is for the Computer Records
CDIRECTORY="/tmp/JSS_Report/Computers"
if [ ! -d "$CDIRECTORY" ]; then
  mkdir /tmp/JSS_Report/Computers
fi

#Lets get the current User
USER=$(whoami)

# Since we like Data we can also do a timestamp
TIME=$(date +"%d.%m.%y")

# Command to download the XML and strip all content except for the headers into a .txt file to be used by the CSV
HEADERS=$(curl -H "Accept: text/xml" -sfku "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedcomputersearches/name/${JSSSEARCH}" | xmllint --format - | xpath /advanced_computer_search/display_fields 2>&1 | grep -B1 "<name>" | awk -F'>|<' '/<name>/{print $3}' | sort -n | sed "s/$/,/g" > ${DIRECTORY}/headernumber.txt)

xmlFileDownload=$(curl -H "Accept: text/xml" -sfku "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedcomputersearches/name/${JSSSEARCH}" | xmllint --format - > ${DIRECTORY}/${JSSSEARCH}.xml)
xmlFile=${DIRECTORY}/${JSSSEARCH}.xml

#Exports the data from the header.txt file to be into a .CSV named Correctly
unset Tags[@]
for (( i=1 ; i<=$(xmllint --xpath "count(//computer)" ${xmlFile}) ; i++ ))
do
	for (( j=1 ; j<=$(xmllint --xpath "count(//computer[${i}]/*)" ${xmlFile}) ; j++ ))
	do
		Tags=( "${Tags[@]}" "$(xmllint --xpath "name(//computer[${i}]/*[${j}])" ${xmlFile})" )
		 echo "$(xmllint --xpath "name(//computer[${i}]/*[${j}])" ${xmlFile})" >> ${DIRECTORY}/Header.xml
	done
done


#Get Number of Lines from headers to split the Base Report Up by this is necessary as the reports will have different number of display fields
COUNT=$(wc -l < ${DIRECTORY}/headernumber.txt)


#Read the Full Header.XML and strip out all but the relevant Fields for the Headers of the CSV	
cat ${DIRECTORY}/Header.xml | awk '!/id/' | awk '!/name/' | awk '!/udid/' 2>&1 | sed "s/$/,/g" | awk 'FNR <= '"$COUNT"'' > ${DIRECTORY}/header.txt

#Command to convert the Header.txt to the Report name .csv
awk 'BEGIN { ORS = " " } { print }' ${DIRECTORY}/header.txt > ${DIRECTORY}/${JSSSEARCH}.${TIME}.csv

#Command to download the same XML as before but this time strip out all unnecessary data and leave the computer content
REPORT=$(cat ${xmlFile} | xmllint --format - | xpath /advanced_computer_search/computers/computer | awk '!/<id>/' | awk '!/<name>/' | awk '!/<udid>/' | awk '!/<Make>/' | awk '!/<computer>/' 2>&1 | sed -e 's/<[^>]*>//g' | sed "s/$/,/g" > ${DIRECTORY}/Computers.txt)

#Command to split the Computers.txt file up into individual computer records based on number of display fields read from headers file
awk 'NR%'"$COUNT"'==1{close (x);x="/tmp/JSS_Report/Computers/Computer"++i;}{printf > x;}' /private/tmp/JSS_Report/Computers.txt



#Get number of files in a directory for second count
#the Dircount shows the wrong number as the xml split creates a extra empty file so we will update with the next variable
DIRCOUNT=$(ls -l ${DIRECTORY}/Computers| wc -l)

#This is the more accurate Record count of the machines
RECORD=$[$DIRCOUNT-2]


#Add an extra , into the CSV so that the records enter into the new line
echo "," >> ${DIRECTORY}/${JSSSEARCH}.${TIME}.csv

#Define a starting number for the index to increment
index="0"

#Loop through the Computers Folder and output each record into the CSV
while [ $index -lt ${RECORD} ] 
do
	#Increment our count by 1 for each execution
	index=$[$index+1]
	
	#Convert the raw txt file into a CSV format
	COMPUTER=$(awk 'BEGIN { ORS = " " } { printf }' ${DIRECTORY}/Computers/Computer${index}) 
	
	
	#Insert the converted record into the CSV report
	echo $COMPUTER >> ${DIRECTORY}/${JSSSEARCH}.${TIME}.csv
	
	
done

mv ${DIRECTORY}/${JSSSEARCH}.${TIME}.csv /Users/$USER/Desktop/

#Lets get cleaning
rm -rf ${DIRECTORY}
