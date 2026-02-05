Additional Queries to Add
1. Top Actors by Change Count (Counter + Table)
Query: Top 5 Most Active Users
sql-- Query Name: "top_actors_change_count"
SELECT 
  user_identity.email as user_email,
  COUNT(*) as total_changes,
  COUNT(DISTINCT service_name) as services_affected,
  COUNT(DISTINCT action_name) as unique_actions,
  MAX(event_time) as last_change
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
GROUP BY user_identity.email
ORDER BY total_changes DESC
LIMIT 10;
Visualization: Table

Shows: Who made the most changes
Columns: user, total changes, services touched, action types, last activity


2. Changes by Service (Pie Chart)
sql-- Query Name: "changes_by_service"
SELECT 
  service_name,
  COUNT(*) as change_count
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
GROUP BY service_name
ORDER BY change_count DESC;
Visualization: Pie Chart or Bar Chart

Shows: Which services have the most configuration changes


3. Changes Over Time (Trend Line)
sql-- Query Name: "changes_trend_over_time"
SELECT 
  DATE(event_time) as date,
  COUNT(*) as daily_changes,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
GROUP BY DATE(event_time)
ORDER BY date;
Visualization: Line Chart

X-axis: date
Y-axis: daily_changes
Second line: unique_users
Shows: Activity trends over the last 30 days


4. Top Action Types (Bar Chart)
sql-- Query Name: "top_action_types"
SELECT 
  action_name,
  service_name,
  COUNT(*) as action_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
GROUP BY action_name, service_name
ORDER BY action_count DESC
LIMIT 15;
Visualization: Horizontal Bar Chart

Shows: Most common action types


5. Failed Changes (Alert Widget)
sql-- Query Name: "failed_changes"
SELECT 
  event_time,
  user_identity.email as user_email,
  service_name,
  action_name,
  response.status_code,
  response.error_message,
  CASE 
    WHEN service_name = 'unityCatalog' AND action_name IN ('deleteTable', 'deleteVolume')
      THEN CONCAT(
        COALESCE(request_params.catalog_name, ''), '.', 
        COALESCE(request_params.schema_name, ''), '.', 
        COALESCE(request_params.table_name, request_params.name, '')
      )
    WHEN service_name = 'clusters' 
      THEN CONCAT('Cluster: ', COALESCE(request_params.cluster_name, request_params.cluster_id))
    ELSE CONCAT(service_name, ' - ', action_name)
  END as attempted_change
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND response.status_code != 200  -- Failed operations
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
ORDER BY event_time DESC
LIMIT 50;
Visualization: Table (with red highlighting)

Shows: Failed configuration change attempts
Useful for: Security monitoring (unauthorized attempts)


6. KPI Counters (Add to Top of Dashboard)
Total Changes (30 days)
sql-- Query Name: "kpi_total_changes_30d"
SELECT 
  COUNT(*) as total_changes
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  );
Visualization: Counter | Label: "Total Changes (30d)"

Unique Actors
sql-- Query Name: "kpi_unique_actors_30d"
SELECT 
  COUNT(DISTINCT user_identity.email) as unique_actors
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  );
Visualization: Counter | Label: "Unique Actors (30d)"

Failed Changes
sql-- Query Name: "kpi_failed_changes_30d"
SELECT 
  COUNT(*) as failed_changes
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND response.status_code != 200
  AND (
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  );
