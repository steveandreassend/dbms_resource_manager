/*
PDB Performance Profiles
================================
A PDB performance profile configures resource plan directives for a set of PDBs that have the same priorities and resource controls.

Resource Plan Directives
================================
Directives control allocation of CPU and parallel execution servers.

shares
================================
The `shares` parameter within the context of Oracle Database's Resource Manager, particularly when configuring CDB profile directives for Pluggable Databases (PDBs),
is a key component in managing CPU resource distribution. This parameter determines the relative amount of CPU resources allocated to a PDB or consumer group under CPU contention.

Here’s how `shares` work:

- **Relative Importance**: The value assigned to `shares` indicates the relative importance or priority of a PDB or consumer group compared to others. A higher number
of shares grants a higher priority for receiving CPU resources when these resources are contested.

- **CPU Allocation**: When multiple PDBs or consumer groups are competing for CPU, the Database Resource Manager allocates CPU resources based on the proportion of shares
assigned to each. For instance, if you have two consumer groups, A and B, with shares set to 3 and 2 respectively, group A would receive 3/5 of the CPU resources, and group B
would receive 2/5, under conditions where CPU resources are insufficient to meet the total demand.

- **Dynamic Adjustment**: Unlike static resource allocation methods, the shares system allows for dynamic adjustment of CPU resource distribution based on the current workload
and the defined priorities. This ensures that more critical or higher-priority workloads can maintain performance under varying load conditions.

The `shares` parameter is used to establish a tiered performance model where PDBs associated with the `gold` profile are given higher priority over those with `silver` or `bronze`.
This is particularly useful in environments where multiple applications with varying performance and priority requirements are hosted within the same database infrastructure,
allowing for more flexible and efficient use of resources.

utilization_limit
================================
The CPU utilization limit for sessions connected to a PDB is set by the utilization_limit parameter in subprograms of the DBMS_RESOURCE_MANAGER package.
The utilization_limit parameter specifies the percentage of the system resources that a PDB can use. The value ranges from 0 to 100.

parallel_server_limit
================================
Limit the number of parallel execution servers (PQ) in a PDB by means of parallel statement queuing. The limit is a “queuing point” because the database queues parallel
queries when the limit is reached. This is a percentage.

PQ will be activiated automatically if this is configured within the PDB:
ALTER SESSION SET PARALLEL_DEGREE_POLICY = AUTO;

*/

exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN(
    plan    => 'newcdb_plan',
    comment => 'CDB resource plan for soft partitioning the hardware resources across PDB tiers');
END;
/

/*
Create performance profiles called Gold, Silver, and Bronze. Each profile specifies a different set of directives depending on the importance of the type of PDB.
Gold PDBs are more mission critical than Silver PDBs, which are more mission critical than Bronze PDBs.
A PDB specifies its performance profile with the DB_PERFORMANCE_PROFILE initialization parameter.

*/
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PROFILE_DIRECTIVE(
    plan                  => 'newcdb_plan', 
    profile               => 'gold', 
    shares                => 3, 
    utilization_limit     => 60,
    parallel_server_limit => 60);
END;
/

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PROFILE_DIRECTIVE(
    plan                  => 'newcdb_plan', 
    profile               => 'silver', 
    shares                => 2, 
    utilization_limit     => 30,
    parallel_server_limit => 30);
END;
/

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PROFILE_DIRECTIVE(
    plan                  => 'newcdb_plan', 
    profile               => 'bronze', 
    shares                => 1, 
    utilization_limit     => 10,
    parallel_server_limit => 10);
END;
/

/* Update the default plan for new PDBs */
BEGIN
  DBMS_RESOURCE_MANAGER.UPDATE_CDB_DEFAULT_DIRECTIVE(
    plan                      => 'newcdb_plan', 
    new_shares                => 1, 
    new_utilization_limit     => 10,
    new_parallel_server_limit => 10);
END;
/

/*
  Update the AutoTask directive in a CDB resource plan using the UPDATE_CDB_AUTOTASK_DIRECTIVE procedure.
  The AutoTask directive applies to automatic maintenance tasks that are run in the root maintenance window.
*/
BEGIN
  DBMS_RESOURCE_MANAGER.UPDATE_CDB_AUTOTASK_DIRECTIVE(
    plan                  => 'newcdb_plan', 
    new_shares            => 2, 
    new_utilization_limit => 60);
END;
/

  
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();

exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();

ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = 'newcdb_plan' SCOPE=BOTH;

/* review config */
COLUMN PLAN FORMAT A30
COLUMN STATUS FORMAT A10
COLUMN COMMENTS FORMAT A35
 
SELECT PLAN, STATUS, COMMENTS 
FROM   DBA_CDB_RSRC_PLANS 
ORDER BY PLAN;

/*
Use PDB lockdown profiles to specify PDB initialization parameters that control resources, such as SGA_TARGET and PGA_AGGREGATE_LIMIT.
A lockdown profile prevents the PDB administrator from modifying the settings.

To prevent PDB owners from switching profiles, Oracle recommends putting the PDB performance profile in the PDB lockdown profile.
*/
-- Define GOLD Lockdown Profile with Performance Settings
BEGIN
  DBMS_LOCKDOWN.create_profile(profile_name => 'GOLD');
  
  -- Lock DB_PERFORMANCE_PROFILE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_DB_PERFORMANCE_PROFILE', clause => 'DB_PERFORMANCE_PROFILE', option => 'ALTER SYSTEM');
  
  -- Lock MAX_IOPS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_MAX_IOPS', clause => 'MAX_IOPS', option => 'ALTER SYSTEM');
  
  -- Lock MAX_MBPS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_MAX_MBPS', clause => 'MAX_MBPS', option => 'ALTER SYSTEM');
  
  -- Lock SESSIONS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_SESSIONS', clause => 'SESSIONS', option => 'ALTER SYSTEM');
  
  -- Lock PGA_AGGREGATE_TARGET parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_PGA_AGGREGATE_TARGET', clause => 'PGA_AGGREGATE_TARGET', option => 'ALTER SYSTEM');
  
  -- Lock PGA_AGGREGATE_LIMIT parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_PGA_AGGREGATE_LIMIT', clause => 'PGA_AGGREGATE_LIMIT', option => 'ALTER SYSTEM');
  
  -- Lock SGA_TARGET parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_SGA_TARGET', clause => 'SGA_TARGET', option => 'ALTER SYSTEM');
  
  -- Lock SGA_MIN_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_SGA_MIN_SIZE', clause => 'SGA_MIN_SIZE', option => 'ALTER SYSTEM');
  
  -- Lock SHARED_POOL_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_SHARED_POOL_SIZE', clause => 'SHARED_POOL_SIZE', option => 'ALTER SYSTEM');
  
  -- Lock DB_CACHE_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'GOLD', rule_name => 'LOCK_DB_CACHE_SIZE', clause => 'DB_CACHE_SIZE', option => 'ALTER SYSTEM');

END;
/

-- Define SILVER Lockdown Profile with Performance Settings
BEGIN
  DBMS_LOCKDOWN.create_profile(profile_name => 'SILVER');
  
  -- Lock DB_PERFORMANCE_PROFILE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_DB_PERFORMANCE_PROFILE', clause => 'DB_PERFORMANCE_PROFILE', option => 'ALTER SYSTEM');
  
  -- Lock MAX_IOPS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_MAX_IOPS', clause => 'MAX_IOPS', option => 'ALTER SYSTEM');
  
  -- Lock MAX_MBPS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_MAX_MBPS', clause => 'MAX_MBPS', option => 'ALTER SYSTEM');
  
  -- Lock SESSIONS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_SESSIONS', clause => 'SESSIONS', option => 'ALTER SYSTEM');
  
  -- Lock PGA_AGGREGATE_TARGET parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_PGA_AGGREGATE_TARGET', clause => 'PGA_AGGREGATE_TARGET', option => 'ALTER SYSTEM');
  
  -- Lock PGA_AGGREGATE_LIMIT parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_PGA_AGGREGATE_LIMIT', clause => 'PGA_AGGREGATE_LIMIT', option => 'ALTER SYSTEM');
  
  -- Lock SGA_TARGET parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_SGA_TARGET', clause => 'SGA_TARGET', option => 'ALTER SYSTEM');
  
  -- Lock SGA_MIN_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_SGA_MIN_SIZE', clause => 'SGA_MIN_SIZE', option => 'ALTER SYSTEM');
  
  -- Lock SHARED_POOL_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_SHARED_POOL_SIZE', clause => 'SHARED_POOL_SIZE', option => 'ALTER SYSTEM');
  
  -- Lock DB_CACHE_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'SILVER', rule_name => 'LOCK_DB_CACHE_SIZE', clause => 'DB_CACHE_SIZE', option => 'ALTER SYSTEM');

END;
/

-- Define BRONZE Lockdown Profile with Performance Settings
BEGIN
  DBMS_LOCKDOWN.create_profile(profile_name => 'BRONZE');
  
  -- Lock DB_PERFORMANCE_PROFILE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_DB_PERFORMANCE_PROFILE', clause => 'DB_PERFORMANCE_PROFILE', option => 'ALTER SYSTEM');
  
  -- Lock MAX_IOPS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_MAX_IOPS', clause => 'MAX_IOPS', option => 'ALTER SYSTEM');
  
  -- Lock MAX_MBPS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_MAX_MBPS', clause => 'MAX_MBPS', option => 'ALTER SYSTEM');
  
  -- Lock SESSIONS parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_SESSIONS', clause => 'SESSIONS', option => 'ALTER SYSTEM');
  
  -- Lock PGA_AGGREGATE_TARGET parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_PGA_AGGREGATE_TARGET', clause => 'PGA_AGGREGATE_TARGET', option => 'ALTER SYSTEM');
  
  -- Lock PGA_AGGREGATE_LIMIT parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_PGA_AGGREGATE_LIMIT', clause => 'PGA_AGGREGATE_LIMIT', option => 'ALTER SYSTEM');
  
  -- Lock SGA_TARGET parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_SGA_TARGET', clause => 'SGA_TARGET', option => 'ALTER SYSTEM');
  
  -- Lock SGA_MIN_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_SGA_MIN_SIZE', clause => 'SGA_MIN_SIZE', option => 'ALTER SYSTEM');
  
  -- Lock SHARED_POOL_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_SHARED_POOL_SIZE', clause => 'SHARED_POOL_SIZE', option => 'ALTER SYSTEM');
  
  -- Lock DB_CACHE_SIZE parameter
  DBMS_LOCKDOWN.add_rule(profile_name => 'BRONZE', rule_name => 'LOCK_DB_CACHE_SIZE', clause => 'DB_CACHE_SIZE', option => 'ALTER SYSTEM');

END;
/

/* for each PDB, assign a profile and restart it */
--ALTER SESSION SET CONTAINER=mypdb1;
--ALTER SYSTEM SET DB_PERFORMANCE_PROFILE=gold SCOPE=spfile;
--ALTER SYSTEM SET PDB_LOCKDOWN=gold SCOPE=spfile;
--ALTER PLUGGABLE DATABASE CLOSE IMMEDIATE;
--ALTER PLUGGABLE DATABASE OPEN;


