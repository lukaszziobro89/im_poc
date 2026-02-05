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
