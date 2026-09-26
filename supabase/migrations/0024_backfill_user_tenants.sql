-- 0024_backfill_user_tenants.sql
-- Repair orphaned pre-0023 users: accounts registered between 0021 (first
-- user_tenants / current_tenant_id) and 0023 (register_tenant stamps
-- membership) have a users-row tenant_id but NO user_tenants membership, so
-- get_user_tenants() returns [] and the app can't resolve a workspace.
--
-- This is an idempotent data backfill replicating 0021's migration-time
-- insert; safe to re-run on any environment (staging/prod) since the primary
-- key (user_id, tenant_id) dedupes.

begin;

-- 1. Backfill missing user_tenants memberships from users.tenant_id.
insert into public.user_tenants (user_id, tenant_id, role)
select id, tenant_id, role
from public.users
where tenant_id is not null
  and role in ('admin', 'accountant', 'sales')
on conflict (user_id, tenant_id) do nothing;

-- 2. Backfill current_tenant_id for users stamped before 0021 (mirror of 0021).
update public.users
set current_tenant_id = tenant_id
where tenant_id is not null
  and current_tenant_id is null;

commit;