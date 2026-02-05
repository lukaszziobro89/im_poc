SELECT 
  event_time,
  user_identity.email as user_email,
  service_name,
  action_name,
  response.status_code,
  source_ip_address
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    -- Permission changes
    (service_name = 'accounts' AND action_name IN ('createGroup', 'add', 'addPrincipalToGroup', 'removePrincipalFromGroup', 'revokeDbToken'))
    OR (service_name = 'workspace' AND action_name = 'updatePermissionAssignment')
    OR (service_name = 'sqlPermissions' AND action_name IN ('grantPermission', 'requestPermissions'))
    OR (service_name = 'unityCatalog' AND action_name IN ('updatePermissions', 'UpdateTagSecurableAssignments'))
    OR (service_name = 'clusterPolicies' AND action_name IN ('changeClusterPolicyAcl', 'create'))
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    
    -- Resource changes
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
ORDER BY event_time DESC
LIMIT 200;
