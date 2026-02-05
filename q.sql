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



SELECT 
  event_time,
  user_identity.email as user_email,
  service_name,
  action_name,
  
  -- Extract what was changed based on service
  CASE 
    -- Accounts: User/Group changes
    WHEN service_name = 'accounts' AND action_name = 'createGroup' 
      THEN CONCAT('Group: ', request_params.displayName)
    WHEN service_name = 'accounts' AND action_name IN ('addPrincipalToGroup', 'removePrincipalFromGroup')
      THEN CONCAT('User: ', request_params.userName, ' → Group: ', request_params.groupId)
    WHEN service_name = 'accounts' AND action_name = 'revokeDbToken'
      THEN CONCAT('Token ID: ', request_params.tokenId)
    
    -- Workspace permissions
    WHEN service_name = 'workspace' AND action_name = 'updatePermissionAssignment'
      THEN CONCAT('Principal: ', request_params.principal, ' → Permissions: ', request_params.permissions)
    
    -- SQL permissions
    WHEN service_name = 'sqlPermissions'
      THEN CONCAT('Object: ', request_params.objectType, ' → ', request_params.objectId)
    
    -- Unity Catalog permissions
    WHEN service_name = 'unityCatalog' AND action_name = 'updatePermissions'
      THEN CONCAT(
        request_params.securable_type, ': ',
        COALESCE(request_params.full_name, request_params.catalog_name, request_params.schema_name, request_params.table_name)
      )
    
    -- Unity Catalog tags
    WHEN service_name = 'unityCatalog' AND action_name = 'UpdateTagSecurableAssignments'
      THEN CONCAT('Tags on: ', request_params.securable_type, ' ', request_params.securable_name)
    
    -- Unity Catalog data objects
    WHEN service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema')
      THEN CONCAT(action_name, ': ', request_params.name)
    WHEN service_name = 'unityCatalog' AND action_name IN ('createTable', 'deleteTable', 'updateTables')
      THEN CONCAT(
        COALESCE(request_params.catalog_name, ''), '.', 
        COALESCE(request_params.schema_name, ''), '.', 
        COALESCE(request_params.table_name, request_params.name, '')
      )
    WHEN service_name = 'unityCatalog' AND action_name IN ('createVolume', 'deleteVolume')
      THEN CONCAT(
        COALESCE(request_params.catalog_name, ''), '.', 
        COALESCE(request_params.schema_name, ''), '.', 
        COALESCE(request_params.name, '')
      )
    
    -- Cluster Policy
    WHEN service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl'
      THEN CONCAT('Policy ID: ', request_params.cluster_policy_id)
    
    -- Clusters
    WHEN service_name = 'clusters' AND action_name IN ('create', 'delete')
      THEN CONCAT('Cluster: ', COALESCE(request_params.cluster_name, request_params.cluster_id))
    
    -- Secrets
    WHEN service_name = 'secrets' AND action_name = 'createScope'
      THEN CONCAT('Scope: ', request_params.scope)
    WHEN service_name = 'secrets' AND action_name = 'putAcl'
      THEN CONCAT('Scope: ', request_params.scope, ' → Principal: ', request_params.principal)
    
    ELSE 'See request_params'
  END as change_details,
  
  response.status_code,
  source_ip_address,
  request_params  -- Keep full params for reference
  
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
    OR (service_name = 'clusterPolicies' AND action_name = 'changeClusterPolicyAcl')
    OR (service_name = 'secrets' AND action_name IN ('createScope', 'putAcl'))
    
    -- Critical resource changes
    OR (service_name = 'unityCatalog' AND action_name IN ('createCatalog', 'createSchema', 'deleteTable', 'deleteVolume', 'createTable', 'updateTables', 'createVolume'))
    OR (service_name = 'clusters' AND action_name IN ('create', 'delete'))
  )
ORDER BY event_time DESC
LIMIT 200;
