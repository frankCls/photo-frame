Privacy Policy for Raspberry Pi Photo Frame

Last updated: 16-12-2025

This Privacy Policy describes how the Raspberry Pi Photo Frame ("we", "our", or "the Application") collects, uses, and discloses your information, specifically in relation to your use of Google Drive services.

1. Introduction

The Raspberry Pi Photo Frame is a DIY software project designed to synchronize and display personal photos from a user's Google Drive account onto a local display device (Raspberry Pi). The Application is designed for personal use.

2. Information We Collect

To function correctly, the Application accesses the following data from your Google Account via the Google Drive API:

Authentication Tokens: We store OAuth 2.0 refresh tokens and access tokens locally on your Raspberry Pi to maintain a connection to your Google Drive without requiring frequent re-login.

File Metadata: We access the names, sizes, IDs, and modification times of files in the specific folder you designate for synchronization.

File Content: We download the actual image files (photos) from the designated folder to the local storage of the Raspberry Pi for display purposes.

We do NOT collect:

Your Google Account password.

Information about files outside the specific folder(s) you configure.

Personal contacts or email data.

3. How We Use Your Information

The information collected is used solely for the functionality of the device:

Display: To render your photos on the connected screen.

Synchronization: To ensure the local cache on the Raspberry Pi matches the contents of your Google Drive folder (downloading new photos and removing deleted ones).

4. How We Share Your Information

We do not share, sell, or transfer your personal data to any third parties.

All data downloaded from Google Drive is stored locally on your specific Raspberry Pi hardware.

The Application does not transmit your photos or metadata to any external servers, analytics providers, or advertising networks.

Communication happens directly between your Raspberry Pi and Google's servers.

5. Data Retention and Deletion

Retention: Photos are retained locally on the Raspberry Pi's storage media (SD card) as long as they exist in your source Google Drive folder.

Deletion: If you delete a photo from your Google Drive source folder, the Application (via the synchronization script) will delete the corresponding local copy from the Raspberry Pi during the next scheduled sync cycle.

Revoking Access: You can revoke the Application's access to your Google Drive at any time via your Google Account Security Settings. Deleting the local configuration files on the Raspberry Pi will also remove the stored access tokens.

6. Security

The Application uses standard OAuth 2.0 protocols for authentication. Your credentials (client secrets and tokens) are stored in configuration files on the Raspberry Pi. You are responsible for securing physical and network access to your Raspberry Pi to prevent unauthorized access to these tokens.

7. Google API Services User Data Policy

The Raspberry Pi Photo Frame's use and transfer to any other app of information received from Google APIs will adhere to the Google API Services User Data Policy, including the Limited Use requirements.

8. Contact Information

If you have any questions about this Privacy Policy, please contact:

Frank Claes