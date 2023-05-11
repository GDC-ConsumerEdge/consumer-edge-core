# Robin Software Defined Storage for Kubernetes

The default setting for Consumer Edge currently leverage Robion Cloud Native Storage for Kubernetes. This requires subscribing to a license via Google Cloud Marketplace which will begin billing immeidately. Only proceed if you have authorization to commit spend on your project.

1. In order to setup the RobinIO secret:

    1. Go to Google Cloud Marketplace, search for "Robin Cloud Native Storage"
    1. Click on "Robin Cloud Native Storage"
    1. Click "Configure" and then "Deploy via Command Line"
    1. Select the Robin Reporting Service Account (or create a new one)
    1. Check the box for "I accept the GCP Marketplace Terms of Service"
    1. WARNING NEXT STEPS INCURE BILLING CHARGERS - STOP NOW IF YOU DO NOT HAVE AUTHORIZATION TO COMMIT TO SPEND
    1. Click "Download License Key" and save to a known location on your workstation
    1. Go to "Secret Manager" in Google Cloud Console and create a Google Secret named "robin-sds-license"
    1. Contents of that secret is a JSON blob in the following format (locate the items from the License Key file that was downloaded 2 steps above to complete this JSON blob):

        ```json
        {
          "consumer-id": "project:pr-xxxddddd-change-me",
          "entitlement-id": "xxxxxxxx-2450-4dca-9abe-b8-change-me",
          "reporting-key": "ewogICJ0eXBlIjogInNl...change-me..."
        }