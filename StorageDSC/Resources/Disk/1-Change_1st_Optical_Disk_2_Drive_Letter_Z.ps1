<#PSScriptInfo
.VERSION 1.0.0
.GUID 3f629ab7-358f-4d82-8c0a-556e32514e3e
.AUTHOR DSC Community
.COMPANYNAME DSC Community
.COPYRIGHT Copyright the DSC Community contributors. All rights reserved.
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/StorageDsc/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/StorageDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module StorageDsc

<#
    .DESCRIPTION
        This configuration will look for first optical disk drive
        and change it's drive letter to Z.
#>
Configuration OpticalDiskDriveLetter_SetDriveLetter
{
    Import-DSCResource -ModuleName StorageDsc

    Node localhost
    {
        OpticalDiskDriveLetter SetFirstOpticalDiskDriveLetterToZ
        {
            DiskId      = 1
            DriveLetter = 'Z'
        }
    }
}