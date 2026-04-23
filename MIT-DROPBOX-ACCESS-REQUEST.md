# MIT Dropbox API Access Request Guide

## Background
You're trying to use the Dropbox API with your MIT account (mabdel03@mit.edu), but MIT uses Dropbox Business which restricts API access to team administrators.

## Issue
When trying to generate an access token at https://www.dropbox.com/developers/apps, you receive:
```
"You must be a team administrator to perform this operation."
```

## Solutions

### Solution 1: Request Token from MIT Dropbox Admin ⭐ RECOMMENDED

**Step 1: Contact MIT IT**
- Help Desk: https://ist.mit.edu/help
- Email: servicedesk@mit.edu
- Phone: 617-253-1101

**Step 2: Use This Request Template**

```
Subject: Dropbox API Access Token Request - Research Project

Hi MIT IT Team,

I'm working on a research project with OHSU that requires programmatic access 
to upload CSV data files to my MIT Dropbox account.

Request Details:
- MIT Account: mabdel03@mit.edu
- Project: OHSU Visual Acuity Test (iOS Clinical Trial App)
- Purpose: Automated upload of clinical trial data (CSV files)
- Data Type: De-identified patient visual acuity test results
- Required Permission: files.content.write (file upload only)
- Token Type: Non-expiring OAuth 2.0 access token

Could you please either:
1. Generate a non-expiring access token for me, OR
2. Grant me temporary permissions to create OAuth apps

App Configuration Needed:
- App Name: OHSU Visual Acuity Test
- API Type: Scoped access
- Access Type: Full Dropbox (or App folder)
- Required Scopes: files.content.write
- Token Expiration: No expiration

Target Upload Path: /Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials/

Please let me know if you need any additional information or if there's a formal 
process I should follow for this request.

Thank you!
Mahmoud Abdelmoneum
mabdel03@mit.edu
```

**Step 3: Wait for Response**
MIT IT will either:
- Generate the token and send it to you securely
- Grant you app creation privileges
- Provide alternative instructions

**Step 4: Update the Code**
Once you receive the token, update `DropboxUploadManager.swift`:
```swift
private let accessToken = "your-token-from-mit-it"
```

---

### Solution 2: Request Admin Privileges

If you need ongoing access to create/manage apps:

**Request:**
```
Subject: Request for Dropbox App Creation Privileges

Hi MIT IT Team,

I would like to request permissions to create Dropbox OAuth applications for 
my research work. This would allow me to integrate Dropbox storage with research 
applications I'm developing.

Could you please grant my account (mabdel03@mit.edu) the ability to create and 
manage OAuth apps in the MIT Dropbox Business account?

Purpose: Clinical trial data collection and storage for OHSU collaboration

Thank you!
```

---

### Solution 3: OAuth 2.0 Authorization Flow (Technical Alternative)

If MIT IT cannot provide a token, implement user-based OAuth instead.

**Pros:**
- Users authorize with their own accounts
- No admin intervention needed after initial app registration
- More secure (tokens stored per device)

**Cons:**
- More complex implementation
- Still requires MIT admin to register the app initially
- Users must authorize on each device

**Would require:**
1. MIT admin to register the app and provide App Key/Secret
2. Implementing OAuth flow in your iOS app
3. Secure token storage in iOS Keychain

---

### Solution 4: MIT-Specific Dropbox Policies

MIT may have specific policies or approved processes for API access:

**Check these resources:**
1. MIT IS&T Dropbox Documentation: https://ist.mit.edu/dropbox
2. MIT Data Protection Policies: https://policies.mit.edu/
3. MIT API Access Policies (if they exist)

**Questions to ask MIT IT:**
- Does MIT have a standard process for Dropbox API access?
- Are there pre-approved apps or templates?
- Do I need IRB approval for storing clinical data?
- Are there MIT-approved alternatives to Dropbox?

---

## Timeline Expectations

- **Token request**: Usually 1-3 business days
- **Admin privileges request**: May take longer (1-2 weeks)
- **OAuth app registration**: Similar to token request

## Security Considerations

When discussing with MIT IT, emphasize:
- ✅ Data is de-identified (no PHI if applicable)
- ✅ Tokens will be stored securely in code (not shared)
- ✅ App only needs write access (files.content.write)
- ✅ Files uploaded to specific folder only
- ✅ Research project with OHSU oversight

## If MIT IT Denies Access

Alternative approaches:
1. Use personal Dropbox for development/testing, MIT Dropbox for production
2. Use MIT's preferred storage solution (Google Drive, OneDrive, etc.)
3. Store locally on device and manual export
4. Use MIT's research data storage (if available)

## Next Steps

1. ✅ Draft email to MIT IT using template above
2. ⏳ Submit request through appropriate channel
3. ⏳ Wait for response (follow up after 2-3 days if no response)
4. ✅ Update code with received token
5. ✅ Test upload functionality
6. ✅ Document token securely for future reference

---

## Contact Information

**MIT IS&T Help:**
- Website: https://ist.mit.edu/help
- Email: servicedesk@mit.edu
- Phone: 617-253-1101
- Hours: Mon-Fri, 8am-8pm ET

**MIT Dropbox Support:**
- May have dedicated Dropbox admin team
- Ask servicedesk for Dropbox-specific contact

---

## Backup Plan

While waiting for MIT approval, you can:
1. Continue development using a personal Dropbox account
2. Switch to MIT account before production deployment
3. Code is already set up - just swap the token

The `DropboxUploadManager.swift` file only needs one line changed:
```swift
private let accessToken = "new-token-here"
```

Everything else stays the same!

