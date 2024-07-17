variable "tags" {
  description = "tags to apply to all resources"
  type        = map(string)
  default = {
    ApplicationName = "poc-infinitt-dotnet"
    GithubRepo      = "terraform-aws-vpc"
    GithubOrg       = "terraform-aws-modules"
  }

}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "DotnetS3SourceZipFile" {
  description = "An S3 URI to a zip file containing a .NET web application. The web application must have been published for the `win-x64` runtime. For example, `dotnet publish --configuration release --runtime win-x64"
  type        = string
  default     = "s3://dc-mysample-dotnet/sample-web-application.zip"
}

variable "DotnetBinaryName" {
  description = "The .NET binary file to execute. This file must exist within the root of the zip file referenced in `DotnetS3SourceZipFile`."
  type        = string
  default     = "sample-web-application.exe"
}

variable "WebsiteName" {
  description = "The website name. This is used for local folder paths on the image, and is used for the Windows Service."
  type        = string
  default     = "DotnetWebsiteDemo"

}

variable "TCPPort" {
  description = "The TCP Port for the .NET web application. This should match the port configured in the .NET web application."
  type        = number
  default     = 5000

}

variable "HTMLTitleValidationString" {
  description = "A string that should exist between the HTML <Title> and </Title> tags. This string is used for validating the website is available."
  type        = string
  default     = "Home page - hello_powershell_summit"

}
