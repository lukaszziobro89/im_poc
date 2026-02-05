-- Find all potential security configuration change actions
SELECT 
  service_name,
  action_name,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_identity.email) as unique_users
FROM system.access.audit
WHERE 
  event_date >= current_date() - INTERVAL 30 DAYS
  AND user_identity.subject_type = 'USER'
  AND (
    -- Look for modification verbs
    action_name LIKE 'create%'
    OR action_name LIKE 'update%'
    OR action_name LIKE 'delete%'
    OR action_name LIKE 'grant%'
    OR action_name LIKE 'revoke%'
    OR action_name LIKE 'add%'
    OR action_name LIKE 'remove%'
    OR action_name LIKE 'put%'
    OR action_name LIKE '%Grant%'
    OR action_name LIKE '%Revoke%'
    OR action_name LIKE '%Permission%'
    OR action_name LIKE '%Policy%'
    OR action_name LIKE '%Member%'
    OR action_name LIKE '%Assignment%'
  )
  -- Exclude obvious read operations
  AND action_name NOT LIKE 'get%'
  AND action_name NOT LIKE 'list%'
  AND action_name NOT LIKE 'describe%'
GROUP BY service_name, action_name
ORDER BY service_name, event_count DESC;
