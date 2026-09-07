-- 0012_storage.sql
-- Tenant-isolated storage bucket for generated documents (PDF statements,
-- invoices). Path convention: {tenant_id}/{folder}/{filename} — the first
-- path segment MUST be the owning tenant's UUID, which is what the RLS
-- policies assert.
-- The statement-pdf Edge Function (M3) is the writer; the Flutter app reads
-- through the same tenant-scoped policies.

begin;

insert into storage.buckets (id, name, public)
values ('pdfs', 'pdfs', false)
on conflict (id) do nothing;

-- storage.objects RLS is already enabled by Supabase by default; do NOT
-- ALTER storage tables from the editor (42501 — they belong to
-- supabase_storage_admin). Just add our bucket-scoped policies.

-- Tenant can only see their own folder.
create policy tenant_isolated_pdf_select on storage.objects
    for select
    using (
        bucket_id = 'pdfs'
        and (storage.foldername(name))[1] = (select public.get_my_tenant_id()::text)
    );

-- Tenant can only write into their own folder.
create policy tenant_isolated_pdf_insert on storage.objects
    for insert
    with check (
        bucket_id = 'pdfs'
        and (storage.foldername(name))[1] = (select public.get_my_tenant_id()::text)
    );

-- Tenant can delete only from their own folder.
create policy tenant_isolated_pdf_delete on storage.objects
    for delete
    using (
        bucket_id = 'pdfs'
        and (storage.foldername(name))[1] = (select public.get_my_tenant_id()::text)
    );

commit;     