create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'operador' check (role in ('admin', 'operador', 'leitura')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  sku text unique,
  category text,
  description text,
  unit text,
  min_stock numeric(14, 3) not null default 0 check (min_stock >= 0),
  location text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stock_balances (
  product_id uuid primary key references public.products(id) on delete cascade,
  quantity numeric(14, 3) not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  movement_type text not null check (movement_type in ('entrada', 'saida', 'ajuste')),
  quantity numeric(14, 3) not null check (quantity > 0),
  previous_quantity numeric(14, 3) not null check (previous_quantity >= 0),
  next_quantity numeric(14, 3) not null check (next_quantity >= 0),
  reason text not null check (length(trim(reason)) > 0),
  destination text,
  reference text,
  notes text,
  performed_by uuid references auth.users(id),
  idempotency_key uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create index if not exists products_active_idx on public.products(active);
create index if not exists stock_movements_product_created_idx
  on public.stock_movements(product_id, created_at desc);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row execute procedure public.set_updated_at();

drop trigger if exists stock_balances_set_updated_at on public.stock_balances;
create trigger stock_balances_set_updated_at
before update on public.stock_balances
for each row execute procedure public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.stock_balances enable row level security;
alter table public.stock_movements enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
on public.profiles for select to authenticated
using (auth.uid() = id);

drop policy if exists products_select_authenticated on public.products;
create policy products_select_authenticated
on public.products for select to authenticated
using (true);

drop policy if exists products_insert_authenticated on public.products;
create policy products_insert_authenticated
on public.products for insert to authenticated
with check (true);

drop policy if exists products_update_authenticated on public.products;
create policy products_update_authenticated
on public.products for update to authenticated
using (true)
with check (true);

drop policy if exists stock_balances_select_authenticated on public.stock_balances;
create policy stock_balances_select_authenticated
on public.stock_balances for select to authenticated
using (true);

drop policy if exists stock_movements_select_authenticated on public.stock_movements;
create policy stock_movements_select_authenticated
on public.stock_movements for select to authenticated
using (true);

create or replace function public.register_stock_movement(
  p_product_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_reason text,
  p_destination text default null,
  p_reference text default null,
  p_notes text default null,
  p_idempotency_key uuid default null
)
returns table (
  movement_id uuid,
  product_id uuid,
  movement_type text,
  quantity numeric,
  previous_quantity numeric,
  next_quantity numeric,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current numeric;
  v_next numeric;
  v_created_at timestamptz;
  v_idempotency_key uuid := coalesce(p_idempotency_key, gen_random_uuid());
  v_existing public.stock_movements;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if p_movement_type not in ('entrada', 'saida', 'ajuste') then
    raise exception 'invalid_movement_type';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity_must_be_positive';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'reason_is_required';
  end if;

  select * into v_existing
  from public.stock_movements
  where idempotency_key = v_idempotency_key;

  if v_existing.id is not null then
    return query
    select v_existing.id, v_existing.product_id, v_existing.movement_type,
      v_existing.quantity, v_existing.previous_quantity, v_existing.next_quantity,
      v_existing.created_at;
    return;
  end if;

  if not exists (
    select 1 from public.products where id = p_product_id and active = true
  ) then
    raise exception 'product_not_found_or_inactive';
  end if;

  insert into public.stock_balances (product_id, quantity)
  values (p_product_id, 0)
  on conflict (product_id) do nothing;

  select quantity into v_current
  from public.stock_balances
  where product_id = p_product_id
  for update;

  if p_movement_type = 'entrada' then
    v_next := v_current + p_quantity;
  elsif p_movement_type = 'saida' then
    if p_quantity > v_current then
      raise exception 'insufficient_stock';
    end if;
    v_next := v_current - p_quantity;
  else
    v_next := p_quantity;
  end if;

  insert into public.stock_movements (
    product_id, movement_type, quantity, previous_quantity, next_quantity,
    reason, destination, reference, notes, performed_by, idempotency_key
  ) values (
    p_product_id, p_movement_type, p_quantity, v_current, v_next,
    trim(p_reason), nullif(trim(p_destination), ''), nullif(trim(p_reference), ''),
    nullif(trim(p_notes), ''), auth.uid(), v_idempotency_key
  )
  returning id, created_at into movement_id, v_created_at;

  update public.stock_balances
  set quantity = v_next
  where public.stock_balances.product_id = p_product_id;

  product_id := p_product_id;
  movement_type := p_movement_type;
  quantity := p_quantity;
  previous_quantity := v_current;
  next_quantity := v_next;
  created_at := v_created_at;
  return next;
end;
$$;

revoke execute on function public.register_stock_movement(uuid, text, numeric, text, text, text, text, uuid) from public;
revoke execute on function public.register_stock_movement(uuid, text, numeric, text, text, text, text, uuid) from anon;
grant execute on function public.register_stock_movement(uuid, text, numeric, text, text, text, text, uuid) to authenticated;
