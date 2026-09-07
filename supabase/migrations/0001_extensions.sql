-- 0001_extensions.sql
-- Enable required Postgres extensions for Hasad.
-- pgcrypto : gen_random_uuid() for UUID primary keys
-- pg_cron  : scheduled daily runs (due reminders, Batch 6)
-- pg_net   : outbound HTTP from SQL (n8n webhooks, Batch 6)

create extension if not exists pgcrypto;
create extension if not exists pg_cron;
create extension if not exists pg_net;