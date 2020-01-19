# VMware View Monitor Scripts

## Overview
Windows Powershell scripts intended to run on a schedule to monitor VMware Horizon View for provisioning
issues and collect various stats that are missing in Horizon View versions 5 through 6.

## Pool Statistics
pool-stats.ps1  collects statistics on VMs within selected Horizon View pools. Results are stored in XML format and can
trigger an email report if desired.

## Pool Provisioning Alert
pool-provision-alert.ps1 monitors a selected Horizon View pool for issues with provisioning and sends an email alert when
new events are triggered.

## Usage
Store the scripts on a Windows host that has access to the Horizon View connection server(s). Run the scripts as scheduled
tasks with provided parameters. Make sure the host has access to an email relay for alerting.
