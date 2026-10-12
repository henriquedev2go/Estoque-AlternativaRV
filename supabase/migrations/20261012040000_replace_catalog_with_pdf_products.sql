-- Substitui o catálogo atual pelo conteúdo exclusivo do PDF da pasta tabela.
-- A limpeza também remove o histórico de movimentações porque ele referencia os produtos antigos.
delete from public.stock_movements;
delete from public.stock_balances;
delete from public.products;

insert into public.products (name, category, description, stock_known, active)
values
  ('Hidramax 1300', 'Hidramax', null, false, true),
  ('Hidramax 600', 'Hidramax', null, false, true),
  ('Nutrisilo', 'Nutrisilo', null, false, true),
  ('Multicocho 200/250', 'Multicocho', null, false, true),
  ('Multicocho 200 com Pé H', 'Multicocho', null, false, true),
  ('Multicocho Confinamento', 'Multicocho', 'Com pés e parafusos inox', false, true),
  ('Autoabastecimento', 'Protecocho', null, false, true),
  ('Creep', 'Protecocho', null, false, true),
  ('Protecocho 200 (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 250 (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 400 (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 500 (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 600 (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 750 (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 1000 (Cocho 200) (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 1000 (Cocho 250) (Com telhado)', 'Protecocho', null, false, true),
  ('Protecocho 200/250 (Sem telhado)', 'Protecocho', null, false, true),
  ('Protecocho 400/500 (Sem telhado)', 'Protecocho', null, false, true),
  ('Protecocho 600/750 (Sem telhado)', 'Protecocho', null, false, true),
  ('Protecocho 1000 (Sem telhado)', 'Protecocho', null, false, true);
