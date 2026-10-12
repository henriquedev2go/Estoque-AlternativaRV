insert into public.products (name, category, description, stock_known, active)
select seed.name, seed.category, seed.description, false, true
from (values
  ('Hidramax 1300', 'Hidramax', 'Bebedouro de alta capacidade com boia de 1 polegada para fluxo contínuo.'),
  ('Hidramax 600', 'Hidramax', 'O Hidramax 600 proporciona abastecimento contínuo e sem desperdício com seu sistema de auto-nível de água. Ideal para lotes menores e bezerros, mantém o rebanho hidratado com praticidade e fácil limpeza.'),
  ('Nutrisilo', 'Nutrisilo', 'Aliando resistência e funcionalidade, o Nutrisilo garante a proteção do alimento contra chuva, roedores e répteis. Além de facilitar a reposição, mantém os suplementos próximos ao ponto de uso, trazendo muito mais agilidade ao manejo.'),
  ('Multicocho 200/250', 'Multicocho', 'O Multicocho 200 é ideal para suplementação a pasto e semiconfinamento. O Multicocho 250 é leve, resistente e fácil de transportar.'),
  ('Multicocho 200 com Pé H', 'Multicocho', 'O clássico Multicocho 200 com Pé H para maior altura do chão.'),
  ('Multicocho Confinamento', 'Multicocho', 'Cocho para confinamento, rápido de montar e fácil de manejar. Uma solução durável e modular, que cresce junto com o seu rebanho.'),
  ('Protecocho Autoabastecimento', 'Protecocho', 'Sistema autoalimentador de alta capacidade para suprimento contínuo.'),
  ('Creep Feeding', 'Protecocho', 'Cocho exclusivo para filhotes, garante alimentação durante a amamentação.'),
  ('Protecocho 200', 'Protecocho', 'Cocho coberto de 300 litros, ideal para suplementação proteica a pasto.'),
  ('Protecocho 250', 'Protecocho', 'Ideal para fornecimento de sal mineral.'),
  ('Protecocho 400', 'Protecocho', 'Alta capacidade para grandes rebanhos e fazendas extensivas.'),
  ('Protecocho 500', 'Protecocho', 'Ideal para fornecimento de sal mineral.'),
  ('Protecocho 600', 'Protecocho', null),
  ('Protecocho 750', 'Protecocho', null),
  ('Protecocho 1000 (Cocho 200)', 'Protecocho', null),
  ('Protecocho 1000 (Cocho 250)', 'Protecocho', null),
  ('Protecocho 200/250 (Sem telhado)', 'Protecocho', null),
  ('Protecocho 400/500 (Sem telhado)', 'Protecocho', null),
  ('Protecocho 600/750 (Sem telhado)', 'Protecocho', null),
  ('Protecocho 1000 (Sem telhado)', 'Protecocho', null)
) as seed(name, category, description)
where not exists (
  select 1 from public.products existing
  where lower(existing.name) = lower(seed.name)
);
