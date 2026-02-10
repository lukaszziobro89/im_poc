Dashboard Queries - Sensitive Table Access Monitoring
Main Query: Detailed Access Log
sql-- Query Name: "sensitive_table_access_detailed"
SELECT 
  a.event_time,
  a.user_identity.email as user_email,
  a.user_identity.subject_type as user_type,
  a.action_name,
  
  -- Table info
  CONCAT(a.request_params.catalog_name, '.', 
         a.request_params.schema_name, '.', 
         a.request_params.table_name) as table_full_name,
  
  -- Execution context
  a.request_params.notebook_path,
  a.request_params.job_id,
  a.request_params.warehouse_id,
  
  -- From registry
  st.sensitivity_level,
  st.description,
  st.sensitivity_reason,
  
  -- Operation category
  CASE 
    WHEN a.action_name = 'getTable' THEN 'READ_METADATA'
    WHEN a.action_name = 'generateTemporaryTableCredential' THEN 'READ_DATA'
    WHEN a.action_name = 'createTable' THEN 'CREATE'
    WHEN a.action_name = 'updateTables' THEN 'MODIFY'
    ELSE a.action_name
  END as operation_category,
  
  a.response.status_code,
  a.source_ip_address
  
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN (
    'getTable',
    'createTable',
    'updateTables',
    'generateTemporaryTableCredential'
  )
  AND a.event_date >= current_date() - INTERVAL 90 DAYS
ORDER BY a.event_time DESC
LIMIT 200;

KPI 1: Total Access (24h)
sql-- Query Name: "kpi_sensitive_table_access_24h"
SELECT 
  COUNT(*) as total_access
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_time >= current_timestamp() - INTERVAL 24 HOURS;
Visualization: Counter | Label: "Table Access (24h)"

KPI 2: Unique Users (24h)
sql-- Query Name: "kpi_unique_users_24h"
SELECT 
  COUNT(DISTINCT a.user_identity.email) as unique_users
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_time >= current_timestamp() - INTERVAL 24 HOURS;
Visualization: Counter | Label: "Unique Users (24h)"

KPI 3: Failed Access (24h)
sql-- Query Name: "kpi_failed_access_24h"
SELECT 
  COUNT(*) as failed_attempts
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND a.response.status_code != 200;
Visualization: Counter (Red) | Label: "Failed Access (24h)"

KPI 4: HIGH Sensitivity Access (24h)
sql-- Query Name: "kpi_high_sensitivity_access_24h"
SELECT 
  COUNT(*) as high_sensitivity_access
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND st.sensitivity_level = 'HIGH';
Visualization: Counter (Orange) | Label: "HIGH Sensitivity Access (24h)"

Query 5: Access Trend Over Time
sql-- Query Name: "sensitive_table_access_trend_7d"
SELECT 
  DATE_TRUNC('hour', a.event_time) as hour,
  COUNT(*) as access_count,
  COUNT(DISTINCT a.user_identity.email) as unique_users,
  COUNT(DISTINCT CONCAT(a.request_params.catalog_name, '.', 
                        a.request_params.schema_name, '.', 
                        a.request_params.table_name)) as unique_tables
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
GROUP BY DATE_TRUNC('hour', a.event_time)
ORDER BY hour;
Visualization: Line Chart

X-axis: hour
Y-axis: access_count
Additional lines: unique_users, unique_tables


Query 6: Access by Sensitivity Level
sql-- Query Name: "access_by_sensitivity_level_7d"
SELECT 
  st.sensitivity_level,
  COUNT(*) as access_count,
  COUNT(DISTINCT a.user_identity.email) as unique_users
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
GROUP BY st.sensitivity_level
ORDER BY 
  CASE st.sensitivity_level
    WHEN 'HIGH' THEN 1
    WHEN 'MEDIUM' THEN 2
    WHEN 'LOW' THEN 3
  END;
Visualization: Bar Chart or Pie Chart

Query 7: Access by Operation Type
sql-- Query Name: "access_by_operation_7d"
SELECT 
  CASE 
    WHEN a.action_name = 'getTable' THEN 'READ_METADATA'
    WHEN a.action_name = 'generateTemporaryTableCredential' THEN 'READ_DATA'
    WHEN a.action_name = 'createTable' THEN 'CREATE'
    WHEN a.action_name = 'updateTables' THEN 'MODIFY'
    ELSE a.action_name
  END as operation_category,
  COUNT(*) as access_count,
  COUNT(DISTINCT a.user_identity.email) as unique_users
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
GROUP BY operation_category
ORDER BY access_count DESC;
Visualization: Bar Chart

Query 8: Top 10 Most Accessed Tables
sql-- Query Name: "top_accessed_tables_7d"
SELECT 
  CONCAT(a.request_params.catalog_name, '.', 
         a.request_params.schema_name, '.', 
         a.request_params.table_name) as table_full_name,
  st.sensitivity_level,
  st.description,
  COUNT(*) as access_count,
  COUNT(DISTINCT a.user_identity.email) as unique_users,
  MAX(a.event_time) as last_access
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
GROUP BY table_full_name, st.sensitivity_level, st.description
ORDER BY access_count DESC
LIMIT 10;
Visualization: Table

Query 9: Top 15 Active Users
sql-- Query Name: "top_users_7d"
SELECT 
  a.user_identity.email as user_email,
  a.user_identity.subject_type as user_type,
  COUNT(*) as access_count,
  COUNT(DISTINCT CONCAT(a.request_params.catalog_name, '.', 
                        a.request_params.schema_name, '.', 
                        a.request_params.table_name)) as tables_accessed,
  MAX(a.event_time) as last_access
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
GROUP BY a.user_identity.email, a.user_identity.subject_type
ORDER BY access_count DESC
LIMIT 15;
Visualization: Table

Query 10: Access by Execution Context
sql-- Query Name: "access_by_context_7d"
SELECT 
  CASE 
    WHEN a.request_params.notebook_path IS NOT NULL THEN 'Notebook'
    WHEN a.request_params.job_id IS NOT NULL THEN 'Scheduled Job'
    WHEN a.request_params.warehouse_id IS NOT NULL THEN 'SQL Warehouse'
    ELSE 'Other'
  END as execution_context,
  COUNT(*) as access_count,
  COUNT(DISTINCT a.user_identity.email) as unique_users
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
GROUP BY execution_context
ORDER BY access_count DESC;
Visualization: Bar Chart or Pie Chart

Query 11: Failed Access Attempts
sql-- Query Name: "failed_access_7d"
SELECT 
  a.event_time,
  a.user_identity.email as user_email,
  a.user_identity.subject_type as user_type,
  CONCAT(a.request_params.catalog_name, '.', 
         a.request_params.schema_name, '.', 
         a.request_params.table_name) as table_full_name,
  st.sensitivity_level,
  a.action_name,
  a.response.status_code,
  a.response.error_message,
  a.source_ip_address
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
  AND a.response.status_code != 200
ORDER BY a.event_time DESC
LIMIT 100;
Visualization: Table (Red highlighting)

Query 12: After-Hours Access
sql-- Query Name: "after_hours_access_7d"
SELECT 
  DATE(a.event_time) as date,
  a.user_identity.email as user_email,
  CONCAT(a.request_params.catalog_name, '.', 
         a.request_params.schema_name, '.', 
         a.request_params.table_name) as table_full_name,
  st.sensitivity_level,
  HOUR(a.event_time) as hour,
  COUNT(*) as access_count
FROM system.access.audit a
INNER JOIN dev_mr_imh_im.monitoring.sensitive_tables st
  ON a.request_params.catalog_name = st.catalog_name
  AND a.request_params.schema_name = st.schema_name
  AND a.request_params.table_name = st.table_name
WHERE 
  a.service_name = 'unityCatalog'
  AND a.action_name IN ('getTable', 'generateTemporaryTableCredential')
  AND a.event_date >= current_date() - INTERVAL 7 DAYS
  AND a.user_identity.subject_type = 'USER'
  AND (
    HOUR(a.event_time) < 7
    OR HOUR(a.event_time) >= 19
    OR DAYOFWEEK(a.event_time) IN (1, 7)
  )
GROUP BY DATE(a.event_time), a.user_identity.email, table_full_name, st.sensitivity_level, HOUR(a.event_time)
ORDER BY date DESC, access_count DESC;
