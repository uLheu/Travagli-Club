-- ============================================================
-- Travagli Club — banco no Supabase (rode tudo no SQL Editor)
-- ============================================================

-- 1) Tabela única: cada "documento" é uma linha, identificada pelo caminho
--    (ex.: 'checkins/abc', 'fichas/uid/avs/src1')
create table if not exists public.docs (
  path text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create index if not exists docs_path_idx on public.docs (path text_pattern_ops);
alter table public.docs enable row level security;
alter table public.docs replica identity full;

-- 2) Tempo real (atualiza o feed ao vivo)
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null;
end $$;

-- 3) Dono = linha 'config/owner' com o seu uid (ver passo 5 do LEIA-ME)
create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.docs where path = 'config/owner' and data->>'uid' = auth.uid()::text);
$$;

-- 4) Quem pode escrever em cada caminho
create or replace function public.can_write(p text, d jsonb) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  -- primeiro dono: só enquanto não existir config/owner, e o uid tem que ser o seu
  if p = 'config/owner' and not exists (select 1 from public.docs where path = 'config/owner') then
    return d->>'uid' = auth.uid()::text;
  end if;
  if public.is_owner() then return true; end if;
  return case split_part(p, '/', 1)
    when 'members'  then split_part(p, '/', 2) = auth.uid()::text   -- cada aluno edita o próprio perfil
    when 'checkins' then d->>'u' = auth.uid()::text
    when 'photos'   then d->>'u' = auth.uid()::text
    when 'likes'    then d->>'u' = auth.uid()::text
    when 'comments' then d->>'u' = auth.uid()::text
    when 'groups'   then true                                         -- convites/aceites (ver delete abaixo)
    else false                                                        -- challenges, fichas, config: só o dono
  end;
end $$;

-- 5) Políticas
drop policy if exists docs_select on public.docs;
drop policy if exists docs_insert on public.docs;
drop policy if exists docs_update on public.docs;
drop policy if exists docs_delete on public.docs;

-- Leitura: tudo para logados, exceto fichas (cada aluno só vê a própria; o dono vê todas)
create policy docs_select on public.docs for select to authenticated using (
  split_part(path, '/', 1) <> 'fichas' or public.is_owner() or split_part(path, '/', 2) = auth.uid()::text
);

create policy docs_insert on public.docs for insert to authenticated with check (public.can_write(path, data));
create policy docs_update on public.docs for update to authenticated
  using (public.can_write(path, data)) with check (public.can_write(path, data));

-- Apagar grupo: só quem criou (ou o dono). Os demais casos seguem can_write.
create policy docs_delete on public.docs for delete to authenticated using (
  case when split_part(path, '/', 1) = 'groups'
       then (public.is_owner() or data->>'by' = auth.uid()::text)
       else public.can_write(path, data) end
);

-- ============================================================
-- Depois de criar o seu usuário em Authentication → Users,
-- rode (troque SEU-UID pelo id que aparece na lista de usuários):
--
-- insert into public.docs (path, data) values ('config/owner', jsonb_build_object('uid', 'SEU-UID'));
-- ============================================================
