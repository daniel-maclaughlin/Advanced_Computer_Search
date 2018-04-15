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
# Written by: Daniel MacLaughlin | Professional Services Engineer | Jamf
# with thanks to Russell Kenny, and the Jamf Professional Services team
#
# Created On: April 14th 2018
# 
# version 2.0
#
# Version 1.1 by Daniel MacLaughlin 21st July 2016
# 
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# VARIABLES
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


JSSURL="https://jamfpro.mycompany.com" #Please be sure to include the port if used
JSSUSER="api"
JSSPASS="api"
SEARCHNAME="" 
#write the Advanced search name as it appears in the jamf server ie "VPN Report if left blank you will be prompted"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# START APPLICATION
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

#Check if no search name was entered then prompt the user

	if [[ $SEARCHNAME == "" ]]; then
	
#######################################
# Create an XSLT file for the Report Display List
#######################################
cat << EOF > /tmp/stylesheet.xslt
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>
<xsl:template match="/"> 
	<xsl:for-each select="//advanced_mobile_device_search"> 
		<xsl:value-of select="name"/>
		<xsl:text>&#xa;</xsl:text> 
	</xsl:for-each> 
</xsl:template> 
</xsl:stylesheet>
EOF

#Get list of Computer Searches
curl -sfk -H "Accept: application/xml" -u "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedmobiledevicesearches" | xsltproc /tmp/stylesheet.xslt - > /tmp/ReportList.txt


SEARCHNAME=$(/usr/bin/osascript <<EOT
	tell application "System Events"
		with timeout of 43200 seconds
			activate
			set ReportList to {}
			set ReportFile to paragraphs of (read POSIX file "/tmp/ReportList.txt")
			repeat with i in ReportFile
				if length of i is greater than 0 then
					copy i to the end of ReportList
				end if
			end repeat
			choose from list ReportList with title "Which Report" with prompt "Please select the report you'd like to run:"
		end timeout
	end tell
EOT)
		
		fi






#Lets get the current User so we can store the report on their Desktop
CURRENTUSER=$(ls -l /dev/console | awk '/ / { print $3 }')

# Since we like Data we can also do a timestamp this can be modified as dd.mm.yyyy or dd-mm-yyyy
TIME=$(date +"%d.%m.%Y")

#Checks if there are spaces in the report name and if so change to %20 for the URL
JSSSEARCH=$(echo "$SEARCHNAME" | sed -e 's/ /%20/g')

#Do an API call to see if the Variables are correct
check=$(curl -sfk -H "Accept: application/xml" -u "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedmobiledevicesearches/name/${JSSSEARCH}")


	if [[ $check == "" ]]; then
		
		echo "Uh Oh something went wrong please check your URL, username, password and Search Name"
		exit 1
	fi

#######################################
# Create an XSLT file for the headers for the second XSLT File
#######################################
cat << EOF > /tmp/stylesheet.xslt
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>
<xsl:template match="/"> 
	<xsl:for-each select="//display_fields/display_field"> 
		<xsl:value-of select="name"/>
		<xsl:text>&#xa;</xsl:text> 
	</xsl:for-each> 
</xsl:template> 
</xsl:stylesheet>
EOF
	


#get display fields and remove the space and add a _ to be used for building the stylesheet
curl -sfk -H "Accept: application/xml" -u "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedmobiledevicesearches/name/${JSSSEARCH}" | xsltproc /tmp/stylesheet.xslt - | sed -e 's/ /_/g' | sed -e 's/-/_/g' | sort > /tmp/header.txt

#This runs the same command however it has an extra sed command to add a , to the end of each record for csv
curl -sfk -H "Accept: application/xml" -u "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedmobiledevicesearches/name/${JSSSEARCH}" | xsltproc /tmp/stylesheet.xslt - | sed -e 's/ /_/g' | sed -e 's/-/_/g' | sed "s/$/,/g" | sort > /tmp/header1.txt

#command to cycle through the csv list and covert to table headers
xargs -n 120 < /tmp/header1.txt > "/Users/$CURRENTUSER/Desktop/${SEARCHNAME}.${TIME}.csv"

#Build the stylesheet with while loop to cycle through the headers.txt and embede the variables in rather than hardcoding
cat << EOF > /tmp/stylesheet.xslt
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>
<xsl:template match="/"> 
	<xsl:for-each select="//mobile_devices/mobile_device"> 
EOF
while read line;do
	echo "<xsl:value-of select="\"$line\""/>" >> /tmp/stylesheet.xslt
	echo "<xsl:text>,</xsl:text>" >> /tmp/stylesheet.xslt
done < /tmp/header.txt
cat << EOL >> /tmp/stylesheet.xslt
<xsl:text>&#xa;</xsl:text>
</xsl:for-each> 
</xsl:template> 
</xsl:stylesheet>
EOL

#this grabs the machines and parses through the new xsltproc and appends to the report on the desktop
curl -sfk -H "Accept: application/xml" -u "${JSSUSER}":"${JSSPASS}" "${JSSURL}/JSSResource/advancedmobiledevicesearches/name/${JSSSEARCH}" | sed -e 's/,/./g'| xsltproc /tmp/stylesheet.xslt - >> "/Users/$CURRENTUSER/Desktop/${SEARCHNAME}.${TIME}.csv"

#lets clean up the files
rm "/tmp/header.txt"
rm "/tmp/header1.txt"
rm "/tmp/stylesheet.xslt"
rm "/tmp/ReportList.txt"
