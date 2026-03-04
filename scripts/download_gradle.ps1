$ErrorActionPreference = 'Stop'
$env:GRADLE_USER_HOME = 'D:\code\zuoye\.gradle-tmp'
$distDir = Join-Path $env:GRADLE_USER_HOME 'wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj'
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
$zip = Join-Path $distDir 'gradle-8.14-all.zip'

$mirrors = @(
	'https://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip',
	'https://mirrors.aliyun.com/gradle/gradle-8.14-all.zip',
	'https://services.gradle.org/distributions/gradle-8.14-all.zip'
)

foreach ($url in $mirrors) {
	try {
		Write-Host "Downloading from $url ..."
		Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
		Write-Host "Downloaded to $zip"
		break
	} catch {
		Write-Warning "Failed from $url : $($_.Exception.Message)"
		if ($url -eq $mirrors[-1]) { throw }
	}
}

# 将 zip 复制到默认用户 Gradle 缓存，避免再次下载
$userDist = Join-Path $env:USERPROFILE '.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj'
New-Item -ItemType Directory -Path $userDist -Force | Out-Null
Copy-Item $zip (Join-Path $userDist 'gradle-8.14-all.zip') -Force
Write-Host "Copied to $userDist"
