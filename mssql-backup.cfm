<!---
====================================
Backup MS SQL databases to Amazon S3
====================================
--->
<cfsetting enablecfoutputonly="false" requestTimeOut="300" showDebugOutput="true">

<cfset request.dsn = "myDatasource">
<cfset request.backupDirectory = "C:/backup/mssql/" />
<cfset request.bucket = "s3://MyBucket/backup">

<!---  leave blank to backup all databases --->
<cfset request.tobackup = ""> 

<cfif ListLen( request.tobackup ) eq 0>
	
	<!--- get list of all databases --->
	<cfquery name="qDatabasesToBackup" datasource="#request.dsn#">
		select name as dbName
		from master.dbo.sysdatabases
		where name <> 'tempdb'
	</cfquery>
	
	<cfset request.tobackup = ValueList( qDatabasesToBackup.dbName )>
	
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

	<cfquery name="requestBackup" datasource="#request.dsn#">
		backup database #dbName#
		to disk='#directory#/#backupfilename#'
		with format
	</cfquery>
	
	<cfoutput>backed up: #directory#/#backupfilename#<br></cfoutput>
	
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