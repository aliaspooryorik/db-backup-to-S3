component
{
	this.name = "s3_backup_" & Hash( getDirectoryFromPath( getCurrentTemplatePath() ) );
		
	// S3 details
	this.s3.accessKeyId = "A1B2C3A1B2C3A1B2C3";
	this.s3.awsSecretKey = "a1b1c1d1e/a1a2a3a4a5a6a7a8a9a0b1b2/c1c2";
	
}