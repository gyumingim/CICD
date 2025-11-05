#!/usr/bin/env pwsh
# This script works on Windows PowerShell, PowerShell Core, Linux, and macOS

Write-Host "Starting Jenkins container..." -ForegroundColor Green

# Detect OS
$isLinux = $PSVersionTable.Platform -eq 'Unix' -or $PSVersionTable.OS -match 'Linux'

if ($isLinux) {
    # Linux/macOS
    docker run -d `
      --name jenkins `
      -p 9090:8080 -p 50000:50000 `
      -v jenkins_home:/var/jenkins_home `
      -v /var/run/docker.sock:/var/run/docker.sock `
      -v "$(which docker):/usr/bin/docker" `
      jenkins/jenkins:lts
} else {
    # Windows
    docker run -d `
      --name jenkins `
      -p 9090:8080 -p 50000:50000 `
      -v jenkins_home:/var/jenkins_home `
      -v //var/run/docker.sock:/var/run/docker.sock `
      jenkins/jenkins:lts
}

Write-Host "Waiting for Jenkins to start (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Jenkins Initial Password:" -ForegroundColor Cyan
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

Write-Host ""
Write-Host "Jenkins installation completed!" -ForegroundColor Green
Write-Host "Access URL: http://localhost:9090" -ForegroundColor White
Write-Host "Copy the password above and use it to login" -ForegroundColor White