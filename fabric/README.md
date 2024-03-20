# Automate Suspend
I use this to shut down my capacity at a certain time to avoid budget issues 😁

1. Create the automation account
1. Select the "Identity" for the Automation Account
1. Update the Fabric Capacity resource to add the Automation Account Identity to "Contributor" 
1. Create a new "Runbook" in the Automation Account
1. Paste the contents of this file into the [Runbook](suspend-capacity.ps1)
1. Save the Runbook
1. Test the Runbook
1. Schedule the Runbook with the correct parameters

