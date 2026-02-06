Perfect! Let's create a dashboard for File System Access to Protected Directories.

Step 1: Discover What File System Operations Exist
First, let's see what file system operations are being logged in your environment:
sql-- Discovery query: Find all file system operations

SELECT 
  service_name,
  action_name,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    service_name = 'filesystem'
    OR service_name = 'dbfs'
    OR service_name = 'workspaceFiles'
  )
GROUP BY service_name, action_name
ORDER BY event_count DESC;
```

---

## **Run This Discovery Query First**

1. Create a new query: `discover_filesystem_operations`
2. Paste the SQL above
3. Run it
4. **Share the results with me**

---

## **Expected Results (Based on Your Earlier Data)**

From your previous output, you have:

| service_name | action_name | What it means |
|--------------|-------------|---------------|
| **filesystem** | `filesGet` | Reading/downloading files |
| **filesystem** | `filesPut` | Writing/uploading files |
| **filesystem** | `directoriesGet` | Reading directory metadata |
| **filesystem** | `list` | Listing directory contents |
| **filesystem** | `createUploadPartUrls` | Initiating file upload |
| **filesystem** | `createDownloadUrl` | Creating file download link |
| **dbfs** | `create` | Creating files (legacy DBFS) |
| **dbfs** | `addBlock` | Writing data blocks (legacy DBFS) |
| **workspaceFiles** | `wsfsStreamingRead` | Reading workspace files |

---

## **Step 2: Define Your "Protected Directories"**

You need to specify **which directories are considered protected**. Common patterns:

### **Typical Protected Directory Patterns:**
```
Unity Catalog Volumes:
  /Volumes/catalog/schema/volume_name
  
Common protected paths:
  /Volumes/*/sensitive/*
  /Volumes/*/confidential/*
  /Volumes/*/pii/*
  /Volumes/prod/*
  /Volumes/*/secure/*
  
Legacy DBFS mounts (if used):
  /mnt/sensitive/
  /mnt/prod/
  /dbfs/protected/

Step 3: Create Protected Paths Registry (If Not Done Yet)
sql-- Check if you already have this table
SELECT * FROM dev_mr_imh_im.monitoring.protected_paths;

-- If not, create it
CREATE TABLE IF NOT EXISTS dev_mr_imh_im.monitoring.protected_paths (
  path_pattern STRING,
  protection_level STRING,
  description STRING,
  created_at TIMESTAMP DEFAULT current_timestamp()
);

-- Insert your protected paths
INSERT INTO dev_mr_imh_im.monitoring.protected_paths 
(path_pattern, protection_level, description)
VALUES
  ('/Volumes/%/sensitive/%', 'HIGH', 'Sensitive data volumes'),
  ('/Volumes/%/confidential/%', 'HIGH', 'Confidential files'),
  ('/Volumes/%/pii/%', 'HIGH', 'Personal Identifiable Information'),
  ('/Volumes/prod/%', 'MEDIUM', 'Production data volumes'),
  ('/mnt/sensitive/%', 'HIGH', 'Legacy sensitive mount'),
  ('/dbfs/protected/%', 'MEDIUM', 'Protected DBFS paths');
  -- ADD YOUR ACTUAL PROTECTED PATHS HERE

Step 4: Main Dashboard Query - Protected File System Access
sql-- Main query: File System Access to Protected Directories
SELECT 
  event_time,
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  service_name,
  action_name,
  
  -- Extract file path
  request_params.path as file_path,
  
  -- Categorize operation type
  CASE 
    WHEN action_name IN ('filesGet', 'createDownloadUrl', 'wsfsStreamingRead') THEN 'Read/Download'
    WHEN action_name IN ('filesPut', 'createUploadPartUrls', 'create', 'addBlock') THEN 'Write/Upload'
    WHEN action_name IN ('directoriesGet', 'list') THEN 'List/Browse'
    ELSE action_name
  END as operation_type,
  
  -- Extract directory level
  CASE 
    WHEN request_params.path LIKE '/Volumes/%' THEN 
      REGEXP_EXTRACT(request_params.path, '^/Volumes/([^/]+)/([^/]+)/([^/]+)', 0)
    WHEN request_params.path LIKE '/mnt/%' THEN
      REGEXP_EXTRACT(request_params.path, '^/mnt/([^/]+)', 0)
    WHEN request_params.path LIKE '/dbfs/%' THEN
      REGEXP_EXTRACT(request_params.path, '^/dbfs/([^/]+)', 0)
    ELSE 'Other'
  END as directory_root,
  
  -- Determine protection level (join with protected paths)
  COALESCE(
    (SELECT protection_level 
     FROM dev_mr_imh_im.monitoring.protected_paths pp 
     WHERE request_params.path LIKE pp.path_pattern 
     LIMIT 1),
    'UNPROTECTED'
  ) as protection_level,
  
  response.status_code,
  source_ip_address,
  request_params  -- Keep for reference
  
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND action_name IN (
    -- Read operations
    'filesGet',
    'createDownloadUrl',
    'directoriesGet',
    'list',
    'wsfsStreamingRead',
    
    -- Write operations
    'filesPut',
    'createUploadPartUrls',
    'create',
    'addBlock'
  )
  -- Filter only protected paths
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
    -- ADD YOUR PROTECTED PATH PATTERNS HERE
  )
ORDER BY event_time DESC
LIMIT 200;

Alternative: Using JOIN with Protected Paths Table
If you want to use the protected paths table dynamically:
sql-- Main query: Protected File Access (using registry)
WITH protected_access AS (
  SELECT 
    a.event_time,
    a.user_identity.email as user_email,
    a.user_identity.subject_type as user_type,
    a.service_name,
    a.action_name,
    a.request_params.path as file_path,
    a.response.status_code,
    a.source_ip_address,
    pp.protection_level,
    pp.description as path_description,
    
    CASE 
      WHEN a.action_name IN ('filesGet', 'createDownloadUrl', 'wsfsStreamingRead') THEN 'Read/Download'
      WHEN a.action_name IN ('filesPut', 'createUploadPartUrls', 'create', 'addBlock') THEN 'Write/Upload'
      WHEN a.action_name IN ('directoriesGet', 'list') THEN 'List/Browse'
      ELSE a.action_name
    END as operation_type
    
  FROM system.access.audit a
  CROSS JOIN dev_mr_imh_im.monitoring.protected_paths pp
  WHERE 
    a.event_date >= current_date() - INTERVAL 30 DAYS
    AND a.service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
    AND a.request_params.path LIKE pp.path_pattern
)
SELECT * FROM protected_access
ORDER BY event_time DESC
LIMIT 200;

Dashboard Queries - File System Access
1. KPI: Total Protected File Access (Last 24h)
sql-- Query Name: "kpi_protected_file_access_24h"
SELECT 
  COUNT(*) as total_access
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  );
Visualization: Counter | Label: "Protected File Access (24h)"

2. KPI: Unique Users Accessing Protected Files (Last 24h)
sql-- Query Name: "kpi_unique_users_protected_files_24h"
SELECT 
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  );
Visualization: Counter | Label: "Unique Users (24h)"

3. KPI: Failed Access Attempts (Last 24h)
sql-- Query Name: "kpi_failed_file_access_24h"
SELECT 
  COUNT(*) as failed_attempts
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND response.status_code != 200
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  );
Visualization: Counter (Red) | Label: "Failed Access (24h)"

4. Access by Operation Type (Pie Chart)
sql-- Query Name: "file_access_by_operation_30d"
SELECT 
  CASE 
    WHEN action_name IN ('filesGet', 'createDownloadUrl', 'wsfsStreamingRead') THEN 'Read/Download'
    WHEN action_name IN ('filesPut', 'createUploadPartUrls', 'create', 'addBlock') THEN 'Write/Upload'
    WHEN action_name IN ('directoriesGet', 'list') THEN 'List/Browse'
    ELSE 'Other'
  END as operation_type,
  COUNT(*) as access_count
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
GROUP BY operation_type
ORDER BY access_count DESC;
Visualization: Pie Chart

5. Access Trend Over Time
sql-- Query Name: "file_access_trend_30d"
SELECT 
  DATE_TRUNC('hour', event_time) as hour,
  COUNT(*) as access_count,
  COUNT(DISTINCT user_identity.email) as unique_users,
  SUM(CASE WHEN action_name IN ('filesGet', 'createDownloadUrl') THEN 1 ELSE 0 END) as reads,
  SUM(CASE WHEN action_name IN ('filesPut', 'createUploadPartUrls') THEN 1 ELSE 0 END) as writes
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
GROUP BY DATE_TRUNC('hour', event_time)
ORDER BY hour;
Visualization: Line Chart

X-axis: hour
Lines: access_count, reads, writes


6. Top Users by File Access
sql-- Query Name: "top_users_file_access_30d"
SELECT 
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  COUNT(*) as total_access,
  SUM(CASE WHEN action_name IN ('filesGet', 'createDownloadUrl') THEN 1 ELSE 0 END) as reads,
  SUM(CASE WHEN action_name IN ('filesPut', 'createUploadPartUrls') THEN 1 ELSE 0 END) as writes,
  COUNT(DISTINCT request_params.path) as unique_files,
  MAX(event_time) as last_access
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
GROUP BY user_identity.email, user_identity.subject_type
ORDER BY total_access DESC
LIMIT 15;
Visualization: Table

7. Most Accessed Protected Directories
sql-- Query Name: "most_accessed_directories_30d"
SELECT 
  -- Extract top-level directory
  CASE 
    WHEN request_params.path LIKE '/Volumes/%' THEN 
      REGEXP_EXTRACT(request_params.path, '^(/Volumes/[^/]+/[^/]+/[^/]+)', 1)
    WHEN request_params.path LIKE '/mnt/%' THEN
      REGEXP_EXTRACT(request_params.path, '^(/mnt/[^/]+)', 1)
    WHEN request_params.path LIKE '/dbfs/%' THEN
      REGEXP_EXTRACT(request_params.path, '^(/dbfs/[^/]+)', 1)
    ELSE 'Other'
  END as directory_path,
  
  COUNT(*) as access_count,
  COUNT(DISTINCT user_identity.email) as unique_users,
  MAX(event_time) as last_access
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
GROUP BY directory_path
ORDER BY access_count DESC
LIMIT 20;
Visualization: Table or Bar Chart

8. Failed File Access Attempts
sql-- Query Name: "failed_file_access_30d"
SELECT 
  event_time,
  user_identity.email as user_email,
  action_name,
  request_params.path as file_path,
  response.status_code,
  response.error_message,
  source_ip_address
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND response.status_code != 200
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
ORDER BY event_time DESC
LIMIT 50;
Visualization: Table (Red highlighting)

9. After-Hours File Access
sql-- Query Name: "after_hours_file_access_30d"
SELECT 
  DATE(event_time) as date,
  user_identity.email as user_email,
  request_params.path as file_path,
  action_name,
  HOUR(event_time) as hour,
  COUNT(*) as access_count
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND user_identity.subject_type = 'USER'  -- Only human users
  AND (
    HOUR(event_time) < 7        -- Before 7 AM
    OR HOUR(event_time) >= 19   -- After 7 PM
    OR DAYOFWEEK(event_time) IN (1, 7)  -- Weekend
  )
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
GROUP BY DATE(event_time), user_identity.email, request_params.path, action_name, HOUR(event_time)
ORDER BY date DESC, access_count DESC;
Visualization: Table (Orange highlighting)

10. Access by Protection Level
sql-- Query Name: "access_by_protection_level_30d"
SELECT 
  CASE 
    WHEN request_params.path LIKE '/Volumes/%/sensitive/%' THEN 'HIGH'
    WHEN request_params.path LIKE '/Volumes/%/confidential/%' THEN 'HIGH'
    WHEN request_params.path LIKE '/Volumes/%/pii/%' THEN 'HIGH'
    WHEN request_params.path LIKE '/mnt/sensitive/%' THEN 'HIGH'
    WHEN request_params.path LIKE '/Volumes/prod/%' THEN 'MEDIUM'
    WHEN request_params.path LIKE '/dbfs/protected/%' THEN 'MEDIUM'
    ELSE 'LOW'
  END as protection_level,
  COUNT(*) as access_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'dbfs', 'workspaceFiles')
  AND (
    request_params.path LIKE '/Volumes/%/sensitive/%'
    OR request_params.path LIKE '/Volumes/%/confidential/%'
    OR request_params.path LIKE '/Volumes/%/pii/%'
    OR request_params.path LIKE '/Volumes/prod/%'
    OR request_params.path LIKE '/mnt/sensitive/%'
    OR request_params.path LIKE '/dbfs/protected/%'
  )
GROUP BY protection_level
ORDER BY 
  CASE protection_level
    WHEN 'HIGH' THEN 1
    WHEN 'MEDIUM' THEN 2
    WHEN 'LOW' THEN 3
  END;
```

**Visualization:** Bar Chart or Pie Chart

---

## **Dashboard Layout**
```
┌─────────────────────────────────────────────────────────────┐
│  Protected File System Access Dashboard                     │
├──────────────┬──────────────┬──────────────────────────────┤
│ [Counter]    │ [Counter]    │ [Counter]                    │
│ Total Access │ Unique Users │ Failed Access                │
│   (24h)      │   (24h)      │   (24h)                      │
├──────────────┴──────────────┴──────────────────────────────┤
│ [Line Chart: File Access Trend - 30 Days]                  │
│  (Total, Reads, Writes)                                     │
├──────────────────────────┬───────────────────────────────────┤
│ [Pie: Access by Op Type] │ [Bar: Access by Protection Level]│
├──────────────────────────┴───────────────────────────────────┤
│ [Table: Top Users by File Access]                           │
├──────────────────────────────────────────────────────────────┤
│ [Table: Most Accessed Protected Directories]                │
├──────────────────────────────────────────────────────────────┤
│ [Table: Failed File Access Attempts (Red)]                  │
├──────────────────────────────────────────────────────────────┤
│ [Table: After-Hours File Access (Orange)]                   │
├──────────────────────────────────────────────────────────────┤
│ [Table: Detailed File Access Log]                           │
└──────────────────────────────────────────────────────────────┘
