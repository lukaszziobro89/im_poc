Updated Dashboard: Encryption/Decryption + Key GenerationCombined Query: Secrets + Unity Catalog Encryption Operationssql-- Main query: All Encryption/Key Management Operations
SELECT 
  event_time,
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  service_name,
  action_name,
  
  -- Extract operation details based on service
  CASE 
    -- Secrets service
    WHEN service_name = 'secrets' AND action_name = 'getSecret' 
      THEN CONCAT('Secret Retrieved: ', request_params.scope, '/', request_params.key)
    WHEN service_name = 'secrets' AND action_name = 'putSecret' 
      THEN CONCAT('Secret Stored: ', request_params.scope, '/', request_params.key)
    WHEN service_name = 'secrets' AND action_name = 'deleteSecret' 
      THEN CONCAT('Secret Deleted: ', request_params.scope, '/', request_params.key)
    WHEN service_name = 'secrets' AND action_name = 'createScope' 
      THEN CONCAT('Vault Created: ', request_params.scope)
    
    -- Unity Catalog: Table credentials
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryTableCredential'
      THEN CONCAT('Table Key Generated: ', 
        COALESCE(request_params.catalog_name, ''), '.', 
        COALESCE(request_params.schema_name, ''), '.', 
        COALESCE(request_params.table_name, ''))
    
    -- Unity Catalog: Volume credentials
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryVolumeCredential'
      THEN CONCAT('Volume Key Generated: ', 
        COALESCE(request_params.catalog_name, ''), '.', 
        COALESCE(request_params.schema_name, ''), '.', 
        COALESCE(request_params.volume_name, request_params.name, ''))
    
    -- Unity Catalog: Model credentials
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryModelVersionCredential'
      THEN CONCAT('Model Key Generated: ', 
        COALESCE(request_params.full_name, request_params.name, ''))
    
    -- Unity Catalog: List operations
    WHEN service_name = 'unityCatalog' AND action_name = 'listCredentials'
      THEN 'Listed External Storage Credentials'
    WHEN service_name = 'unityCatalog' AND action_name = 'listConnections'
      THEN 'Listed External Connections'
    
    ELSE CONCAT(service_name, ' - ', action_name)
  END as operation_details,
  
  -- Categorize by operation type
  CASE 
    WHEN service_name = 'secrets' AND action_name = 'getSecret' 
      THEN 'Secret Decryption/Retrieval'
    WHEN service_name = 'secrets' AND action_name = 'putSecret' 
      THEN 'Secret Encryption/Storage'
    WHEN service_name = 'secrets' AND action_name = 'deleteSecret' 
      THEN 'Secret Deletion'
    WHEN service_name = 'secrets' AND action_name IN ('createScope', 'deleteScope') 
      THEN 'Secret Vault Management'
    WHEN service_name = 'secrets' AND action_name = 'putAcl' 
      THEN 'Secret Access Control'
    
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryTableCredential'
      THEN 'Data Encryption Key Generation'
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryVolumeCredential'
      THEN 'File Encryption Key Generation'
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryModelVersionCredential'
      THEN 'Model Encryption Key Generation'
    
    WHEN service_name = 'unityCatalog' AND action_name IN ('listCredentials', 'listConnections')
      THEN 'Credential Discovery'
    
    ELSE 'Other'
  END as operation_category,
  
  response.status_code,
  source_ip_address,
  request_params  -- Keep for reference
  
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    -- Secrets service (primary KMS)
    (service_name = 'secrets' AND action_name IN (
      'getSecret',
      'putSecret',
      'deleteSecret',
      'createScope',
      'deleteScope',
      'putAcl'
    ))
    
    -- Unity Catalog encryption key generation
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential',
      'listCredentials',
      'listConnections'
    ))
  )
ORDER BY event_time DESC
LIMIT 200;Additional Queries - Enhanced with Unity Catalog1. KPI: Total Encryption Key Operations (Last 24h)sql-- Query Name: "kpi_total_encryption_ops_24h"
SELECT 
  COUNT(*) as total_operations
FROM system.access.audit
WHERE 
  event_time >= current_timestamp() - INTERVAL 24 HOURS
  AND (
    (service_name = 'secrets' AND action_name = 'getSecret')
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential'
    ))
  );Visualization: Counter | Label: "Encryption Operations (24h)"2. Operations by Type (Pie Chart)sql-- Query Name: "encryption_ops_by_type_30d"
SELECT 
  CASE 
    WHEN service_name = 'secrets' AND action_name = 'getSecret' 
      THEN 'Secret Retrieval'
    WHEN service_name = 'secrets' AND action_name = 'putSecret' 
      THEN 'Secret Storage'
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryTableCredential'
      THEN 'Table Key Generation'
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryVolumeCredential'
      THEN 'Volume Key Generation'
    WHEN service_name = 'unityCatalog' AND action_name = 'generateTemporaryModelVersionCredential'
      THEN 'Model Key Generation'
    ELSE 'Other'
  END as operation_type,
  COUNT(*) as operation_count
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    (service_name = 'secrets')
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential'
    ))
  )
GROUP BY operation_type
ORDER BY operation_count DESC;Visualization: Pie Chart or Bar Chart3. Top Users by Encryption Key Generationsql-- Query Name: "top_users_key_generation_30d"
SELECT 
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  
  -- Count by operation type
  COUNT(*) as total_operations,
  SUM(CASE WHEN action_name = 'generateTemporaryTableCredential' THEN 1 ELSE 0 END) as table_keys,
  SUM(CASE WHEN action_name = 'generateTemporaryVolumeCredential' THEN 1 ELSE 0 END) as volume_keys,
  SUM(CASE WHEN action_name = 'generateTemporaryModelVersionCredential' THEN 1 ELSE 0 END) as model_keys,
  SUM(CASE WHEN service_name = 'secrets' AND action_name = 'getSecret' THEN 1 ELSE 0 END) as secret_retrievals,
  
  MAX(event_time) as last_operation
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    (service_name = 'secrets' AND action_name = 'getSecret')
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential'
    ))
  )
GROUP BY user_identity.email, user_identity.subject_type
ORDER BY total_operations DESC
LIMIT 15;Visualization: Table4. Most Accessed Encrypted Resourcessql-- Query Name: "most_accessed_encrypted_resources_30d"
SELECT 
  CASE 
    WHEN action_name = 'generateTemporaryTableCredential' 
      THEN CONCAT(request_params.catalog_name, '.', request_params.schema_name, '.', request_params.table_name)
    WHEN action_name = 'generateTemporaryVolumeCredential'
      THEN CONCAT(request_params.catalog_name, '.', request_params.schema_name, '.', COALESCE(request_params.volume_name, request_params.name))
    WHEN action_name = 'generateTemporaryModelVersionCredential'
      THEN COALESCE(request_params.full_name, request_params.name)
    WHEN service_name = 'secrets'
      THEN CONCAT(request_params.scope, '/', request_params.key)
  END as resource_name,
  
  CASE 
    WHEN action_name = 'generateTemporaryTableCredential' THEN 'Encrypted Table'
    WHEN action_name = 'generateTemporaryVolumeCredential' THEN 'Encrypted Volume'
    WHEN action_name = 'generateTemporaryModelVersionCredential' THEN 'Encrypted Model'
    WHEN service_name = 'secrets' THEN 'Secret'
  END as resource_type,
  
  COUNT(*) as access_count,
  COUNT(DISTINCT user_identity.email) as unique_users,
  MAX(event_time) as last_accessed
  
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    (service_name = 'secrets' AND action_name = 'getSecret')
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential'
    ))
  )
GROUP BY resource_name, resource_type
ORDER BY access_count DESC
LIMIT 20;Visualization: Table

Shows which encrypted resources (tables, volumes, models, secrets) are accessed most
5. Encryption Operations Trendsql-- Query Name: "encryption_ops_trend_30d"
SELECT 
  DATE_TRUNC('hour', event_time) as hour,
  
  -- Count by service
  SUM(CASE WHEN service_name = 'secrets' THEN 1 ELSE 0 END) as secrets_operations,
  SUM(CASE WHEN service_name = 'unityCatalog' THEN 1 ELSE 0 END) as unity_catalog_keys,
  
  COUNT(*) as total_operations,
  COUNT(DISTINCT user_identity.email) as unique_users
  
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    (service_name = 'secrets' AND action_name = 'getSecret')
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential'
    ))
  )
GROUP BY DATE_TRUNC('hour', event_time)
ORDER BY hour;Visualization: Line Chart

X-axis: hour
Multiple lines: secrets_operations, unity_catalog_keys, total_operations
6. Failed Encryption Operationssql-- Query Name: "failed_encryption_ops_30d"
SELECT 
  event_time,
  user_identity.email as user_email,
  service_name,
  action_name,
  
  CASE 
    WHEN service_name = 'secrets' 
      THEN CONCAT('Secret: ', request_params.scope, '/', request_params.key)
    WHEN action_name = 'generateTemporaryTableCredential'
      THEN CONCAT('Table: ', request_params.catalog_name, '.', request_params.schema_name, '.', request_params.table_name)
    WHEN action_name = 'generateTemporaryVolumeCredential'
      THEN CONCAT('Volume: ', request_params.catalog_name, '.', request_params.schema_name, '.', COALESCE(request_params.volume_name, request_params.name))
    ELSE 'See details'
  END as target_resource,
  
  response.status_code,
  response.error_message,
  source_ip_address
  
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND response.status_code != 200
  AND (
    (service_name = 'secrets')
    OR (service_name = 'unityCatalog' AND action_name IN (
      'generateTemporaryTableCredential',
      'generateTemporaryVolumeCredential',
      'generateTemporaryModelVersionCredential'
    ))
  )
ORDER BY event_time DESC
LIMIT 50;Visualization: Table (Red highlighting)

Shows failed encryption key generation or secret access attempts
