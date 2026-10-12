-- Corrige a ambiguidade entre o parâmetro de saída product_id e a coluna
-- stock_balances.product_id durante o registro de movimentações.
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
  v_recorded_quantity numeric;
  v_created_at timestamptz;
  v_idempotency_key uuid := coalesce(p_idempotency_key, gen_random_uuid());
  v_existing public.stock_movements;
begin
  if not public.is_authorized_user() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_movement_type not in ('entrada', 'saida', 'ajuste') then
    raise exception 'invalid_movement_type';
  end if;

  if p_movement_type = 'ajuste' then
    if p_quantity is null or p_quantity < 0 then
      raise exception 'quantity_must_be_non_negative';
    end if;
  elsif p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity_must_be_positive';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'reason_is_required';
  end if;

  select * into v_existing
  from public.stock_movements as sm
  where sm.idempotency_key = v_idempotency_key;

  if v_existing.id is not null then
    return query
    select v_existing.id, v_existing.product_id, v_existing.movement_type,
      v_existing.quantity, v_existing.previous_quantity, v_existing.next_quantity,
      v_existing.created_at;
    return;
  end if;

  if not exists (
    select 1 from public.products as p
    where p.id = p_product_id and p.active = true
  ) then
    raise exception 'product_not_found_or_inactive';
  end if;

  insert into public.stock_balances (product_id, quantity)
  values (p_product_id, 0)
  on conflict do nothing;

  select sb.quantity into v_current
  from public.stock_balances as sb
  where sb.product_id = p_product_id
  for update;

  if p_movement_type = 'entrada' then
    v_next := v_current + p_quantity;
    v_recorded_quantity := p_quantity;
  elsif p_movement_type = 'saida' then
    if p_quantity > v_current then
      raise exception 'insufficient_stock';
    end if;
    v_next := v_current - p_quantity;
    v_recorded_quantity := p_quantity;
  else
    v_next := p_quantity;
    v_recorded_quantity := abs(v_next - v_current);
    if v_recorded_quantity = 0 then
      raise exception 'adjustment_does_not_change_stock';
    end if;
  end if;

  insert into public.stock_movements as sm (
    product_id, movement_type, quantity, previous_quantity, next_quantity,
    reason, destination, reference, notes, performed_by, idempotency_key
  ) values (
    p_product_id, p_movement_type, v_recorded_quantity, v_current, v_next,
    trim(p_reason), nullif(trim(p_destination), ''), nullif(trim(p_reference), ''),
    nullif(trim(p_notes), ''), auth.uid(), v_idempotency_key
  )
  returning sm.id, sm.created_at into movement_id, v_created_at;

  update public.stock_balances as sb
  set quantity = v_next
  where sb.product_id = p_product_id;

  update public.products as p
  set stock_known = true
  where p.id = p_product_id;

  product_id := p_product_id;
  movement_type := p_movement_type;
  quantity := v_recorded_quantity;
  previous_quantity := v_current;
  next_quantity := v_next;
  created_at := v_created_at;
  return next;
end;
$$;

revoke execute on function public.register_stock_movement(uuid, text, numeric, text, text, text, text, uuid) from public;
revoke execute on function public.register_stock_movement(uuid, text, numeric, text, text, text, text, uuid) from anon;
grant execute on function public.register_stock_movement(uuid, text, numeric, text, text, text, text, uuid) to authenticated;
