-- Discovery query: Find all encryption/secret-related actions
SELECT 
  service_name,
  action_name,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    service_name = 'secrets'
    OR service_name LIKE '%encrypt%'
    OR service_name LIKE '%key%'
    OR action_name LIKE '%secret%'
    OR action_name LIKE '%encrypt%'
    OR action_name LIKE '%decrypt%'
    OR action_name LIKE '%key%'
  )
GROUP BY service_name, action_name
ORDER BY event_count DESC;


-- Find all encryption/key-related operations
SELECT 
  service_name,
  action_name,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND (
    -- Secrets service (primary KMS in Databricks)
    service_name = 'secrets'
    
    -- Unity Catalog credential/token generation (encryption keys)
    OR (service_name = 'unityCatalog' AND (
      action_name LIKE '%Credential%'
      OR action_name LIKE '%Connection%'
      OR action_name LIKE '%Token%'
    ))
    
    -- Any other encryption-related
    OR action_name LIKE '%encrypt%'
    OR action_name LIKE '%decrypt%'
    OR action_name LIKE '%key%'
  )
GROUP BY service_name, action_name
ORDER BY event_count DESC;




-- Main encryption operations dashboard query
SELECT 
  event_time,
  user_identity.email as user_email,
  user_identity.subject_type as user_type,
  action_name,
  
  -- Operation details
  CASE 
    WHEN action_name = 'getSecret' 
      THEN CONCAT('Retrieved: ', request_params.scope, '/', request_params.key)
    WHEN action_name = 'putSecret' 
      THEN CONCAT('Stored: ', request_params.scope, '/', request_params.key)
    WHEN action_name = 'deleteSecret' 
      THEN CONCAT('Deleted: ', request_params.scope, '/', request_params.key)
    WHEN action_name = 'createScope' 
      THEN CONCAT('Created Vault: ', request_params.scope)
    ELSE CONCAT(action_name, ' - ', COALESCE(request_params.scope, 'N/A'))
  END as operation_details,
  
  -- Categorize as encryption operation
  CASE 
    WHEN action_name = 'getSecret' THEN 'Key Decryption/Retrieval'
    WHEN action_name = 'putSecret' THEN 'Key Encryption/Storage'
    WHEN action_name = 'deleteSecret' THEN 'Key Deletion'
    WHEN action_name IN ('createScope', 'deleteScope') THEN 'Key Vault Management'
    WHEN action_name = 'putAcl' THEN 'Key Access Control'
    ELSE 'Other KMS Operation'
  END as kms_operation_type,
  
  response.status_code,
  source_ip_address
  
FROM system.access.audit
WHERE 
  service_name = 'secrets'
  AND event_date >= current_date() - INTERVAL 30 DAYS
ORDER BY event_time DESC
LIMIT 200;
