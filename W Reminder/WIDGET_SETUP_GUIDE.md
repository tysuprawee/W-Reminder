# W Reminder v1.03 Beta: Widget Setup Guide

Since I cannot edit your Xcode Project Settings directly, you need to manually configure the new Widget Target. Follow these steps exactly.

## Step 1: Create the Widget Target
1.  Open your project in **Xcode**.
2.  Go to the top menu bar: **File > New > Target...**
3.  In the template search bar, type **"Widget"**.
4.  Select **"Widget Extension"** and click **Next**.
5.  Fill in the details:
    *   **Product Name**: `WReminderWidget`
    *   **Include Live Activity**: Uncheck this box.
    *   **Include Configuration App Intent**: Uncheck this box (for now, static widgets are simpler).
6.  Click **Finish**.
7.  If a dialog appears asking to "Activate" the scheme, click **Activate**.

## Step 2: Configure App Groups (Crucial for Sharing Data)
This step allows the Widget to see the database created by the Main App.

1.  In the Project Navigator (left sidebar), click on the top-level **"W Reminder"** project icon.
2.  In the main view, select the **"W Reminder"** (Main App) under **TARGETS**.
3.  Click the **"Signing & Capabilities"** tab at the top.
4.  Click the **"+ Capability"** button (top left of the tab).
5.  Search for **"App Groups"** and double-click it.
6.  In the App Groups section that appears:
    *   Click the **"+"** button.
    *   Enter the Group ID: `group.com.tysuprawee.W-Reminder`
    *   **Check the box** next to this new group ID to enable it.
    *   (If you use a different ID, update `SharedPersistence.swift` line 12 code to match).

7.  **Repeat for the Widget Target**:
    *   Select **"WReminderWidget"** under **TARGETS**.
    *   Click **"Signing & Capabilities"**.
    *   Click **"+ Capability"** -> **"App Groups"**.
    *   **Check the box** next to the *SAME* group ID you just created (`group.com.tysuprawee.W-Reminder`).

## Step 3: Add Files to the Widget Target
The Widget code needs access to your data models.

1.  In the Project Navigator, find and select **`SharedPersistence.swift`**.
2.  Open the **File Inspector** (Right Sidebar, first icon).
3.  Under **"Target Membership"**, verify that **W Reminder** is checked.
4.  **Check the box** for **WReminderWidget** as well.
5.  **Repeat this process** (Check both targets) for the following files:
    *   `Checklist.swift`
    *   `SimpleChecklist.swift`
    *   `Tag.swift`
    *   `DeletedRecord.swift`
    *   `Theme.swift` (to avoid color errors)
    *   `dateParser.swift` (if needed, but usually safe to add)

## Step 4: Verify the Widget Code
1.  I have already created the file `WReminderWidget.swift`.
2.  Delete the default `WReminderWidgetBundle.swift` or `WReminderWidget.swift` created by Xcode (if it conflicts).
3.  Ensure my `WReminderWidget.swift` has the correct Target Membership (checked for **WReminderWidget**).

## Step 5: Build and Run
1.  Select the **"W Reminder"** scheme (Main App) and Run.
2.  Create a task or two to populate the database.
3.  Go to the Home Screen.
4.  Long press -> Tap Local "+" -> Search for "W Reminder".
5.  Add the Small (Streak) or Medium (Tasks) widget.
6.  It should immediately show your data!
