<#PSScriptInfo
.VERSION 1.0.1
.GUID 86c0280c-6b48-4689-815d-5bc0692845a4
.AUTHOR DSC Community
.COMPANYNAME DSC Community
.COPYRIGHT DSC Community contributors. All rights reserved.
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/ActiveDirectoryDsc/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/ActiveDirectoryDsc
.ICONURI https://dsccommunity.org/images/DSC_Logo_300p.png
.RELEASENOTES
Updated author, copyright notice, and URLs.
#>

#Requires -Module ActiveDirectoryDsc

<#
    .DESCRIPTION
        This configuration will create a new domain with a new forest and a forest
        functional level of Server 2016.
#>
Configuration ADDomain_NewForest_Config
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DnsForwarder,

        [Parameter(Mandatory = $true)]
        [String]$DomainName,

        [Parameter(Mandatory = $true)]
        [String]$DomainNetBiosName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $SafeModePassword,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName ComputerManagementDSC
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc

    node 'localhost'
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature DNS
        {
            Ensure = "Present"
            Name = "DNS"
        }
        
        WindowsFeature DnsTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }
        
        Script SetDNSForwarder
        {
            #
            # 
            #
            SetScript =
            {
                $dnsrunning = $false
                $triesleft = $Using:RetryCount
                Write-Verbose -Verbose "Checking if DNS service is running."
                While (-not $dnsrunning -and ($triesleft -gt 0))
                {
                    $triesleft--
                    try
                    {
                        $dnsrunning = (Get-Service -name dns).Status -eq "running"
                    } catch {
                        $dnsrunning = $false
                    }
                    if (-not $dnsrunning)
                    {
                        Write-Verbose -Verbose "Waiting $($Using:RetryIntervalSec) seconds for DNS service to start"
                        Start-Sleep -Seconds $Using:RetryIntervalSec
                    }
                }

                $triesleft = $Using:RetryCount
                Write-Verbose "Checking if DNS is responding to WMI."
                do {
                    #
                    # Get-DNSForwarderList would sometimes hang directly after boot.
                    # So, try something with a reasonable timeout first.
                    #
                    try {
                        Write-Verbose -Verbose "Reading DNS through WMI to see if it responds."
                        $dnsObject = Get-CimInstance -ClassName microsoftdns_server -Namespace root/microsoftdns -OperationTimeoutSec 10
                    } catch {
                        $dnsobject = $false
                        Write-Warning -Verbose "Get-Ciminstance for DNS failed: $_"
                    }
                    if ($dnsObject)
                    {
                        $dnsrunning = $true
                    } else {
                        $dnsrunning = $false
                        Write-Verbose -Verbose "Waiting $($Using:RetryIntervalSec) seconds for WMI starting to respond"
                        Start-Sleep -Seconds $Using:RetryIntervalSec
                    }
                    $triesleft--
                } while (-not $dnsrunning -and ($triesleft -gt 0))

                if (-not $dnsrunning)
                {
                    Write-Warning "DNS service is not running, cannot edit forwarder. Template deployment will fail."
                    # but continue anyway.
                }
                try {
                    Write-Verbose -Verbose "Getting list of DNS forwarders"
                    $forwarderlist = Get-DnsServerForwarder
                    if ($forwarderlist.IPAddress)
                    { 
                        Write-Verbose -Verbose "Removing forwarders"
                        Remove-DnsServerForwarder -IPAddress $forwarderlist.IPAddress -Force
                    } else {
                        Write-Verbose -Verbose "No forwarders found"
                    }
                } catch {
                    Write-Warning -Verbose "Exception running Remove-DNSServerForwarder: $_"
                }
                try {
                    Write-Verbose -Verbose "setting  forwarder to $($using:DNSForwarder)"
                    Set-DnsServerForwarder -IPAddress $using:DNSForwarder
                } catch {
                    Write-Warning -Verbose "Exception running Set-DNSServerForwarder: $_"
                }                 
            }
            GetScript =  { @{} }
            TestScript = { $false }
            DependsOn = "[WindowsFeature]DNSTools"
        }

        WindowsFeature ADTools
        {
            Ensure = "Present"
            Name = "RSAT-AD-Tools"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature GPOTools
        {
            Ensure = "Present"
            Name = "GPMC"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature DFSTools
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature 'ADDS'
        {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature 'RSAT'
        {
            Name   = 'RSAT-AD-PowerShell'
            Ensure = 'Present'
        }

        ADDomain 'DomainName'
        {
            DomainName                    = $DomainName
            DomainNetBiosName             = $DomainNetBiosName
            Credential                    = $Credential
            SafemodeAdministratorPassword = $SafeModePassword
            ForestMode                    = 'WinThreshold'
        }

        PendingReboot RebootAfterInstallingAD
        {
            Name = 'RebootAfterInstallingAD'
            DependsOn = "[ADDomain]DomainName"
        }
    }
}