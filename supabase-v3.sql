-- ============================================================
-- Travagli Club — versão 3: treinos montados pelo Léo e biblioteca
-- Rode este arquivo inteiro no SQL Editor (depois do supabase-v2.sql).
-- Pode rodar mais de uma vez.
-- ============================================================

-- Leitura: treinos só aparecem para o próprio aluno e para o dono.
-- Biblioteca só para o dono. Escrita: só o dono (can_write já nega o resto).
drop policy if exists docs_select on public.docs;
create policy docs_select on public.docs for select to authenticated using (
  split_part(path, '/', 1) not in ('fichas', 'sessoes', 'treinos', 'biblioteca')
  or public.is_owner()
  or split_part(path, '/', 2) = auth.uid()::text
);
