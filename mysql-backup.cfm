<!---
===================================
Backup MySQL databases to Amazon S3
===================================
--->
<cfsetting enablecfoutputonly="false" requestTimeOut="300" showDebugOutput="true">

<cfset request.dsn = "myDatasource">
<cfset request.username = "username">
<cfset request.password = "password">
<cfset request.backupDirectory = "C:/backup/mysql/" />
<cfset request.bucket = "s3://MyBucket/backup">

<!---  leave blank to backup all databases --->
<cfset request.tobackup = ""> 

<cfset request.mysqldumppath = "C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqldump">


<cfif ListLen( request.tobackup ) eq 0>
	
	<!--- get list of all databases --->
	<cfquery name="qDatabasesToBackup" datasource="#request.dsn#">
		SHOW DATABASES;
	</cfquery>
	
	<cfset request.tobackup = ValueList( qDatabasesToBackup.Database )>
	
</cfif>

<cfoutput>
<h1>Backup databases</h1>
</cfoutput>

<!--- do the back up --->
<cfloop list="#request.tobackup#" index="dbName">
	
	<cfset directory = "#request.backupDirectory##dbName#">
	<cfset filename = '#dbName#_db_#dateFormat(now(), "YYYYMMDD")##timeFormat(now(), "HHMMSS")#'>
	<cfset backupfilename = '#filename#.BAK'>
	<cfset zipfilename = '#filename#.zip'>
	
	<!--- Create individual directories for each database if they don't exist --->
	<cfif not directoryExists(directory)>
		<cfdirectory action="create" directory="#directory#">
	</cfif>

	<cfexecute name='"#request.mysqldumppath#"'
		arguments=' --user=#request.username# --password=#request.password# --databases --log-error="#directory#" #dbName#'
		outputfile='#directory#/#backupfilename#'
		>
	</cfexecute>
	
	<cfoutput>backed up: #directory#/#backupfilename#<br></cfoutput>
	
	<!--- need to sleep to ensure file is written --->
	<cfset sleep( 100 )>
	
	<!--- zip db backup --->
	
	<cfzip action="zip" source="#directory#/#backupfilename#" 
		file="#directory#/#zipfilename#" 
		overwrite="true">
		
	<cfoutput>created: #directory#/#zipfilename#<br></cfoutput>	
	
	<!--- delete the unzipped file to save disk space --->
	<cffile action="delete" file="#directory#/#backupfilename#">
	
	<cfoutput>deleted: #directory#/#backupfilename#<br></cfoutput>	
	
	<!--- upload to Amazon S3 --->
	<cffile action="copy" 
		source="#directory#/#zipfilename#" 
		destination="#request.bucket#">

	<cfoutput>uploaded to S3<hr></cfoutput>	
		
</cfloop>

<cfoutput>
<h1>Clean up Local backups</h1>
</cfoutput>

<!--- delete old backups to prevent local disk getting very full --->
<cfdirectory action="list" 
	name="qBackups" 
	directory="#request.backupDirectory#" 
	type="file" 
	recurse="yes">
	
<cfquery name="qOldBackups" dbtype="query">
	select * 
	from qBackups
	where dateLastModified < <cfqueryparam value="#CreateODBCDate( DateAdd( 'd', -7, Now() ) )#">
</cfquery>

<cfloop query="qOldBackups">
	<cffile action="delete" file="#qOldBackups.directory#\#qOldBackups.name#">
	<cfoutput>deleted: #qOldBackups.directory#\#qOldBackups.name#<br></cfoutput>	
</cfloop>


<cfoutput>
<h1>Clean up S3 backups</h1>
</cfoutput>


<!--- get directory listing from s3 for added safety only list zip files --->
<cfdirectory action="list" 
	name="qS3Backups" 
	directory="#request.bucket#" 
	filter="*.zip" 
	type="file" 
	recurse="yes">

	
<cfquery name="qS3Backups" dbtype="query">
	select * 
	from qS3Backups 
	where dateLastModified < <cfqueryparam value="#CreateODBCDate( DateAdd( 'd', -14, Now() ) )#">
</cfquery>

<!--- delete old backups from s3 --->
<cfloop query="qS3Backups">
	<cffile action="delete" file="#qS3Backups.directory#\#qS3Backups.name#">
	<cfoutput>deleted: #qS3Backups.directory#\#qS3Backups.name#<br></cfoutput>	
</cfloop>

<cfoutput>
<h1>Completed</h1>
</cfoutput>