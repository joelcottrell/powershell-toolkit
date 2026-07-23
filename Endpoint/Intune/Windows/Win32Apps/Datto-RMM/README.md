# Deploying the Datto RMM Agent using Microsoft Intune

## Overview
Microsoft Intune has functionality to deploy and run PowerShell scripts to Managed Windows 10 devices and Bash and Shell scripts to managed macOS devices, provided that they are fully enrolled in Microsoft Intune and not just Azure AD domain-joined. We can leverage this functionality to deploy scripts that will download and install the Datto RMM Agent.

This repo contains scripts for Windows and macOS to deploy Datto RMM using Microsoft Intune
