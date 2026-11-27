-- ============================================================
-- Travagli Club — versão 2: logbook (séries e cargas) e exercícios
-- Rode este arquivo inteiro no SQL Editor. Pode rodar mais de uma vez.
-- ============================================================

-- Regras de escrita
create or replace function public.can_write(p text, d jsonb) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  if p = 'config/owner' and not exists (select 1 from public.docs where path = 'config/owner') then
    return d->>'uid' = auth.uid()::text;
  end if;
  if public.is_owner() then return true; end if;
  return case split_part(p, '/', 1)
    when 'members'    then split_part(p, '/', 2) = auth.uid()::text   -- cada um edita o próprio perfil
    when 'checkins'   then d->>'u' = auth.uid()::text
    when 'photos'     then d->>'u' = auth.uid()::text
    when 'likes'      then d->>'u' = auth.uid()::text
    when 'comments'   then d->>'u' = auth.uid()::text
    when 'groups'     then true
    when 'sessoes'    then split_part(p, '/', 2) = auth.uid()::text  -- só o próprio logbook
    when 'exercicios' then true                                      -- qualquer aluno cadastra
    else false                                                       -- challenges, fichas, config: só o dono
  end;
end $$;

-- Leitura: sessões do logbook só aparecem para o próprio aluno e para o dono
drop policy if exists docs_select on public.docs;
create policy docs_select on public.docs for select to authenticated using (
  split_part(path, '/', 1) not in ('fichas', 'sessoes')
  or public.is_owner()
  or split_part(path, '/', 2) = auth.uid()::text
);

-- Apagar: grupos (criador ou dono), exercícios (só o dono), resto segue can_write
drop policy if exists docs_delete on public.docs;
create policy docs_delete on public.docs for delete to authenticated using (
  case split_part(path, '/', 1)
    when 'groups'     then (public.is_owner() or data->>'by' = auth.uid()::text)
    when 'exercicios' then public.is_owner()
    else public.can_write(path, data)
  end
);
