-- NEXO Wi-Fi: estrutura inicial para até 10 estabelecimentos
-- Execute este arquivo no Supabase > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.wifi_stores (
  id uuid primary key default gen_random_uuid(),
  business_name text not null,
  network_name text not null,
  wifi_password text not null,
  slug text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.wifi_stores enable row level security;

-- Visitantes podem consultar apenas os campos da página pública de redes ativas.
drop policy if exists "Public can read active WiFi pages" on public.wifi_stores;
create policy "Public can read active WiFi pages"
on public.wifi_stores for select
to anon, authenticated
using (active = true);

-- Somente usuários autenticados podem administrar os cadastros.
drop policy if exists "Admins can manage WiFi stores" on public.wifi_stores;
create policy "Admins can manage WiFi stores"
on public.wifi_stores for all
to authenticated
using (true)
with check (true);

-- Limite de 10 cadastros no banco, mesmo que sejam feitas tentativas simultâneas.
create or replace function public.limit_nexo_wifi_stores()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform pg_advisory_xact_lock(20261111);
    if (select count(*) from public.wifi_stores) >= 10 then
      raise exception 'Limite NEXO Wi-Fi atingido: são permitidos no máximo 10 estabelecimentos.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_nexo_wifi_limit on public.wifi_stores;
create trigger enforce_nexo_wifi_limit
before insert on public.wifi_stores
for each row execute function public.limit_nexo_wifi_stores();

grant select on public.wifi_stores to anon, authenticated;
grant insert, update, delete on public.wifi_stores to authenticated;
