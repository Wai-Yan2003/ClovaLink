# File Groups

File Groups allow you to organize related files into logical collections without moving them from their original locations. Think of them as virtual folders or tags that group files together for easy access.

## Overview

| Concept | Description |
|---------|-------------|
| **File Group** | A named collection of files from anywhere in your file system |
| **Virtual Organization** | Files remain in their original folders but appear together in the group |
| **Visibility** | Groups can be department-wide or private to the creator |
| **Collaboration** | Share related documents as a cohesive package |

## Use Cases

- **Project Collections**: Group all files related to a project across different folders
- **Client Bundles**: Collect contracts, invoices, and reports for a specific client
- **Review Packages**: Assemble documents for approval workflows
- **Personal Organization**: Create private groups for your own workflow

## Creating File Groups

### Method 1: From the Toolbar

1. Navigate to **Files**
2. Click **New Group** (layers icon)
3. Enter a group name and optional description
4. Choose a color for visual identification
5. Click **Create**

### Method 2: From a File

1. Right-click on any file
2. Select **Create Group from File**
3. The file is automatically added to the new group

### Method 3: Multiple Selection

1. Select multiple files (Ctrl/Cmd + click)
2. Right-click and select **Create Group**
3. All selected files are added to the new group

## Managing Groups

### Adding Files to a Group

**Drag and Drop:**
1. Drag any file onto a group card
2. The file is linked to the group (not moved)

**Context Menu:**
1. Right-click a file
2. Select **Add to Group**
3. Choose from your available groups

### Removing Files from a Group

1. Open the group viewer (click on a group card)
2. Find the file you want to remove
3. Click the **Remove from Group** option
4. The file remains in its original location

### Renaming a Group

1. Right-click on the group card
2. Select **Rename**
3. Enter the new name
4. Press Enter or click Save

### Deleting a Group

1. Right-click on the group card
2. Select **Delete Group**
3. Confirm deletion

**Note**: Deleting a group does NOT delete the files. Files remain in their original locations.

## Visibility Modes

Groups have two visibility modes that determine who can see them:

### Department Groups

| Property | Behavior |
|----------|----------|
| **Visibility** | All users in the department can see the group |
| **Location** | Appears in Department Files view |
| **Use Case** | Team collaboration, shared project collections |

### Private Groups

| Property | Behavior |
|----------|----------|
| **Visibility** | Only the creator can see the group |
| **Location** | Appears in Private Files view |
| **Use Case** | Personal organization, draft collections |

### Visibility Lock

Groups are **locked to their original visibility** once created:
- A department group cannot be moved to private files
- A private group cannot be moved to department files
- This ensures consistent access control

## Group Locking

Prevent accidental modifications to important groups:

### Lock a Group

1. Right-click on the group card
2. Select **Lock Group**
3. The group shows a lock icon

### Locked Group Restrictions

| Action | Allowed? |
|--------|----------|
| View files | ✅ Yes |
| Download files | ✅ Yes |
| Add files | ❌ No |
| Remove files | ❌ No |
| Rename group | ❌ No |
| Delete group | ❌ No |

### Unlock a Group

Only the user who locked the group (or an Admin) can unlock:
1. Right-click on the locked group
2. Select **Unlock Group**

## Company Folder Integration

When a group is placed inside a **Company Folder**, special rules apply:

### Behavior Changes

| Aspect | In Regular Folder | In Company Folder |
|--------|-------------------|-------------------|
| **Visibility** | Based on group settings | Visible to all departments |
| **Edit Access** | Owner and allowed users | Admin/SuperAdmin only |
| **Icon Display** | Owner avatar | Building icon |
| **Context Menu** | Full options | View/Download only (non-admins) |

### Moving Groups to Company Folders

Only Admin and SuperAdmin can:
1. Move a group into a company folder
2. Edit groups within company folders
3. Delete groups from company folders

Regular users can only view and download files from groups in company folders.

## Group Viewer

Click on any group card to open the Group Viewer panel:

### Features

- **File List**: See all files in the group with details
- **Quick Actions**: Preview, download, copy, share individual files
- **Search**: Filter files within the group
- **Sorting**: Sort by name, date, size, or type

### Actions Available

| Action | Description |
|--------|-------------|
| **Preview** | Open file in preview modal |
| **Download** | Download file to your device |
| **Copy** | Copy file to clipboard for pasting elsewhere |
| **Share** | Create a share link for the file |
| **Move to Folder** | Move the actual file to a different folder |
| **Remove from Group** | Unlink file from this group |

## Starring Groups

Mark important groups for quick access:

1. Right-click on a group card
2. Select **Star Group**
3. Starred groups appear in your Starred section

## Permissions Summary

| Role | Create Groups | Edit Own | Edit Others | Delete Own | Delete Others |
|------|---------------|----------|-------------|------------|---------------|
| Employee | ✅ | ✅ | ❌ | ✅ | ❌ |
| Manager | ✅ | ✅ | ✅ (dept) | ✅ | ✅ (dept) |
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| SuperAdmin | ✅ | ✅ | ✅ | ✅ | ✅ |

## API Reference

### List Groups

```http
GET /api/groups/{tenant_id}
Authorization: Bearer <token>
```

Query parameters:
- `parent_path`: Filter by folder location
- `visibility`: Filter by `department` or `private`
- `department_id`: Filter by specific department

### Create Group

```http
POST /api/groups/{tenant_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Q4 Reports",
  "description": "All Q4 2024 financial reports",
  "color": "#3B82F6",
  "visibility": "department"
}
```

### Add File to Group

```http
POST /api/groups/{tenant_id}/{group_id}/files
Authorization: Bearer <token>
Content-Type: application/json

{
  "file_ids": ["uuid-1", "uuid-2"]
}
```

### Remove File from Group

```http
DELETE /api/groups/{tenant_id}/{group_id}/files/{file_id}
Authorization: Bearer <token>
```

### Lock/Unlock Group

```http
POST /api/groups/{tenant_id}/{group_id}/lock
POST /api/groups/{tenant_id}/{group_id}/unlock
Authorization: Bearer <token>
```

### Move Group

```http
PUT /api/groups/{tenant_id}/{group_id}/move
Authorization: Bearer <token>
Content-Type: application/json

{
  "target_path": "Projects/2024",
  "target_visibility": "department"
}
```

## Best Practices

1. **Use Descriptive Names**: "Q4 2024 Client Reports" is better than "Reports"
2. **Add Descriptions**: Help others understand the group's purpose
3. **Use Colors**: Assign consistent colors (e.g., red for urgent, blue for projects)
4. **Lock Important Groups**: Prevent accidental changes to finalized collections
5. **Clean Up**: Delete groups that are no longer needed to reduce clutter

## Troubleshooting

### "Cannot move group to private files"

Groups are locked to their original visibility mode. Create a new private group instead.

### "Cannot edit group in company folder"

Only Admin and SuperAdmin roles can modify groups within company folders.

### "File already in group"

Each file can only be added to a group once. The file is already linked.

### "Cannot remove file - name conflict"

A file with the same name exists in the target location. Rename one of the files first.

---

*See also: [Admin Guide](Admin-Guide) | [Security](Security) | [API Reference](API-Reference)*

