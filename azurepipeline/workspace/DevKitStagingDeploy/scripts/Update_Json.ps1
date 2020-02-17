param(
    [string]
    $Environment = "prod",
    $ArduinoConfigFileName = "package_pnp_mxchip_board_preview_index.json"
)

$ErrorActionPreference = "Stop"
$CurrentDir = (Get-Location).Path

Import-Module "C:\Program Files (x86)\WindowsPowerShell\Modules\AzureRM.Profile\4.6.0\AzureRM.Profile.psd1"
Import-Module "C:\Program Files (x86)\WindowsPowerShell\Modules\Azure.Storage\4.2.1\Azure.Storage.psd1"
Import-Module "C:\Program Files (x86)\WindowsPowerShell\Modules\Azure\5.1.2\Azure.psd1"

$CurrentVersion =  Get-Content '.\system_version.txt' | Out-String
$CurrentVersion = $CurrentVersion.ToString().Trim() + "-preview"

echo CurrentVersion ---> $CurrentVersion

$ArduinoPackageFilePath = Join-Path -Path (Get-Location).Path -ChildPath "\TestResult\AZ3166-$CurrentVersion.zip"
$ArduinoPackageBlobName = "AZ3166-" + $CurrentVersion

Write-Host("[$Environment][$StorageAccountName]: Start $Environment Deployment.");

	################################################################################
	#              Step 1: upload AZ3166 package to Azure blob storage             #
	################################################################################

	Write-Host("Step 1: upload AZ3166 package to Azure blob storage");
	$ArduinoPackageContainer = "arduinopackage"
	$PackageInfoContainer = "packageinfo"

	################################################################################
	# Step 2: Calculate package MD5 checksum and Update to  configuration JSON file#
	################################################################################

	Write-Host("Step 2: Calculate package MD5 checksum and Update to  configuration JSON file")

	$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	$ArduinoPackageHash = [System.BitConverter]::ToString($MD5.ComputeHash([System.IO.File]::ReadAllBytes($ArduinoPackageFilePath)))
	$ArduinoPackageHash = $ArduinoPackageHash.ToLower() -replace '-', ''
	Write-Host($ArduinoPackageHash);

	
	$ArduinoConfigJson = Get-Content $ArduinoConfigFileName | Out-String | ConvertFrom-Json

	$totalVersions = $ArduinoConfigJson.packages[0].platforms.Count
	$LastPlatform = ([PSCustomObject]($ArduinoConfigJson.packages[0].platforms[$totalVersions - 1]))

	if ($LastPlatform.version -eq $CurrentVersion)
	{
		# Update the latest version
		$LastPlatform.url = "https://azureboard2.azureedge.net/$Environment/$ArduinoPackageContainer/$ArduinoPackageBlobName"
		$LastPlatform.archiveFileName = $ArduinoPackageBlobName
		$LastPlatform.checksum = "MD5:" + $ArduinoPackageHash
		$LastPlatform.size = (Get-Item $ArduinoPackageFilePath).Length.ToString()
	}
	else
	{
		# Add new version
		$NewPlatform = New-Object PSCustomObject

		$LastPlatform.psobject.properties | % {
			$newPlatform | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value   
		}

		$NewPlatform.version = $CurrentVersion
		$NewPlatform.url = "https://azureboard2.azureedge.net/$Environment/$ArduinoPackageContainer/$ArduinoPackageBlobName"
		$NewPlatform.archiveFileName = $ArduinoPackageBlobName
		$NewPlatform.checksum = "MD5:" + $ArduinoPackageHash
		$NewPlatform.size = (Get-Item $ArduinoPackageFilePath).Length.ToString()

		$ArduinoConfigJson.packages[0].platforms += $newPlatform
		$totalVersions += 1
	}

	Write-Host("Total packages versions: $totalVersions")

	# We only maintain the latest 5 versions
	if ($totalVersions -gt 5)
	{
		# Remove the oldest one
		$ArduinoConfigJson.packages[0].platforms = $ArduinoConfigJson.packages[0].platforms[1..($totalVersions - 1)]
	}

	$ArduinoConfigJson | ConvertTo-Json -Depth 10 | Out-File $ArduinoConfigFileName -Encoding ascii

	# Upload Arduino configuration file to Azure blob storage
	$ArduinoConfigJsonBlobName = "$PackageInfoContainer/$ArduinoConfigFileName"
	

	$ArduinoConfigJsonBlobURL = "https://azureboard2.azureedge.net/$Environment/$ArduinoConfigJsonBlobName"
	Write-Host("Arduino board manager JSON file URI: $ArduinoConfigJsonBlobURL")

	Write-Host("[$Environment][$StorageAccountName]: Deployment completed.");
