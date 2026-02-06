Main Dashboard Query - Protected File System Access
sql-- Main query: File System Access to Protected Directory
SELECT 
  event_time,
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  service_name,
  action_name,
  
  -- File path
  request_params.path as file_path,
  
  -- Categorize operation type
  CASE 
    WHEN action_name IN ('filesGet', 'createDownloadUrl', 'wsfsStreamingRead', 'filesHead') THEN 'Read/Download'
    WHEN action_name IN ('filesPut', 'createUploadUrl') THEN 'Write/Upload'
    WHEN action_name IN ('directoriesGet', 'list') THEN 'List/Browse'
    WHEN action_name IN ('filesDelete', 'directoriesDelete') THEN 'Delete'
    ELSE action_name
  END as operation_type,
  
  response.status_code,
  source_ip_address
  
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND action_name IN (
    -- Read operations
    'filesGet',
    'createDownloadUrl',
    'directoriesGet',
    'list',
    'wsfsStreamingRead',
    'filesHead',
    
    -- Write operations
    'filesPut',
    'createUploadUrl',
    
    -- Delete operations
    'filesDelete',
    'directoriesDelete'
  )
  -- Filter only protected path
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
ORDER BY event_time DESC
LIMIT 200;

KPI 1: Total Protected File Access (Last 24h)
sql-- Query Name: "kpi_protected_file_access_24h"
SELECT 
  COUNT(*) as total_access
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%';
Visualization: Counter | Label: "Protected File Access (24h)"

KPI 2: Unique Users Accessing Protected Files (Last 24h)
sql-- Query Name: "kpi_unique_users_protected_files_24h"
SELECT 
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%';
Visualization: Counter | Label: "Unique Users (24h)"

KPI 3: Failed Access Attempts (Last 24h)
sql-- Query Name: "kpi_failed_file_access_24h"
SELECT 
  COUNT(*) as failed_attempts
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND response.status_code != 200
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%';
Visualization: Counter (Red) | Label: "Failed Access (24h)"

KPI 4: Delete Operations (Last 24h)
sql-- Query Name: "kpi_delete_operations_24h"
SELECT 
  COUNT(*) as delete_count
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND service_name = 'filesystem'
  AND action_name IN ('filesDelete', 'directoriesDelete')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%';
Visualization: Counter (Orange) | Label: "Deletions (24h)"

Query 5: Access by Operation Type (Pie Chart)
sql-- Query Name: "file_access_by_operation_30d"
SELECT 
  CASE 
    WHEN action_name IN ('filesGet', 'createDownloadUrl', 'wsfsStreamingRead', 'filesHead') THEN 'Read/Download'
    WHEN action_name IN ('filesPut', 'createUploadUrl') THEN 'Write/Upload'
    WHEN action_name IN ('directoriesGet', 'list') THEN 'List/Browse'
    WHEN action_name IN ('filesDelete', 'directoriesDelete') THEN 'Delete'
    ELSE 'Other'
  END as operation_type,
  COUNT(*) as access_count
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
GROUP BY operation_type
ORDER BY access_count DESC;
Visualization: Pie Chart

Query 6: Access Trend Over Time
sql-- Query Name: "file_access_trend_30d"
SELECT 
  DATE_TRUNC('hour', event_time) as hour,
  COUNT(*) as total_access,
  COUNT(DISTINCT user_identity.email) as unique_users,
  SUM(CASE WHEN action_name IN ('filesGet', 'createDownloadUrl', 'filesHead') THEN 1 ELSE 0 END) as reads,
  SUM(CASE WHEN action_name IN ('filesPut', 'createUploadUrl') THEN 1 ELSE 0 END) as writes,
  SUM(CASE WHEN action_name IN ('filesDelete', 'directoriesDelete') THEN 1 ELSE 0 END) as deletes
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
GROUP BY DATE_TRUNC('hour', event_time)
ORDER BY hour;
Visualization: Line Chart

X-axis: hour
Y-axis: total_access
Additional lines: reads, writes, deletes


Query 7: Top Users by File Access
sql-- Query Name: "top_users_file_access_30d"
SELECT 
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  COUNT(*) as total_access,
  SUM(CASE WHEN action_name IN ('filesGet', 'createDownloadUrl', 'filesHead') THEN 1 ELSE 0 END) as reads,
  SUM(CASE WHEN action_name IN ('filesPut', 'createUploadUrl') THEN 1 ELSE 0 END) as writes,
  SUM(CASE WHEN action_name IN ('filesDelete', 'directoriesDelete') THEN 1 ELSE 0 END) as deletes,
  COUNT(DISTINCT request_params.path) as unique_files,
  MAX(event_time) as last_access
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
GROUP BY user_identity.email, user_identity.subject_type
ORDER BY total_access DESC
LIMIT 15;
Visualization: Table

Query 8: Most Accessed Files
sql-- Query Name: "most_accessed_files_30d"
SELECT 
  request_params.path as file_path,
  COUNT(*) as access_count,
  COUNT(DISTINCT user_identity.email) as unique_users,
  SUM(CASE WHEN action_name IN ('filesGet', 'createDownloadUrl') THEN 1 ELSE 0 END) as reads,
  SUM(CASE WHEN action_name IN ('filesPut', 'createUploadUrl') THEN 1 ELSE 0 END) as writes,
  MAX(event_time) as last_accessed
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
GROUP BY request_params.path
ORDER BY access_count DESC
LIMIT 20;
Visualization: Table

Query 9: Failed File Access Attempts
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
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND response.status_code != 200
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
ORDER BY event_time DESC
LIMIT 50;
Visualization: Table (Red highlighting)

Query 10: File Deletions
sql-- Query Name: "file_deletions_30d"
SELECT 
  event_time,
  user_identity.email as user_email,
  action_name,
  request_params.path as deleted_file,
  response.status_code,
  source_ip_address
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name = 'filesystem'
  AND action_name IN ('filesDelete', 'directoriesDelete')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
ORDER BY event_time DESC
LIMIT 50;
Visualization: Table (Orange highlighting)

Query 11: After-Hours File Access
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
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND user_identity.subject_type = 'USER'  -- Only human users
  AND (
    HOUR(event_time) < 7        -- Before 7 AM
    OR HOUR(event_time) >= 19   -- After 7 PM
    OR DAYOFWEEK(event_time) IN (1, 7)  -- Weekend
  )
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
GROUP BY DATE(event_time), user_identity.email, request_params.path, action_name, HOUR(event_time)
ORDER BY date DESC, access_count DESC;
Visualization: Table (Orange highlighting)

Query 12: Access by Service
sql-- Query Name: "access_by_service_30d"
SELECT 
  service_name,
  COUNT(*) as access_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND service_name IN ('filesystem', 'workspaceFiles')
  AND request_params.path LIKE '/Volumes/dev_mr_imh_im/files/feedback%'
GROUP BY service_name
ORDER BY access_count DESC;
```
