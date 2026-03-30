--
-- PostgreSQL database dump
--

\restrict I08DVs4PSwWvllqnGEDjyqhxfZz0HKVeYfLgG35e4hqdOgsOakI5lIFpSN1ubvA

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Ubuntu 17.9-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: nfe_vigia; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA nfe_vigia;


ALTER SCHEMA nfe_vigia OWNER TO postgres;

--
-- Name: approval_action; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.approval_action AS ENUM (
    'APROVAR',
    'SOLICITAR_REVISAO'
);


ALTER TYPE nfe_vigia.approval_action OWNER TO postgres;

--
-- Name: condo_role; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.condo_role AS ENUM (
    'MORADOR',
    'SINDICO',
    'SUB_SINDICO',
    'CONSELHO_FISCAL',
    'ZELADOR'
);


ALTER TYPE nfe_vigia.condo_role OWNER TO postgres;

--
-- Name: file_kind; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.file_kind AS ENUM (
    'FOTO_CHAMADO',
    'FOTO_ANTES',
    'FOTO_DEPOIS',
    'ORCAMENTO',
    'NF_MATERIAL',
    'NF_SERVICO',
    'DOSSIER_PDF',
    'OUTRO'
);


ALTER TYPE nfe_vigia.file_kind OWNER TO postgres;

--
-- Name: invoice_type; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.invoice_type AS ENUM (
    'MATERIAL',
    'SERVICO'
);


ALTER TYPE nfe_vigia.invoice_type OWNER TO postgres;

--
-- Name: os_status; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.os_status AS ENUM (
    'CRIADA',
    'EM_COTACAO',
    'AGUARDANDO_APROVACAO',
    'APROVADA',
    'EM_EXECUCAO',
    'FINALIZADA',
    'CANCELADA'
);


ALTER TYPE nfe_vigia.os_status OWNER TO postgres;

--
-- Name: os_type; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.os_type AS ENUM (
    'EMERGENCIAL',
    'PADRAO'
);


ALTER TYPE nfe_vigia.os_type OWNER TO postgres;

--
-- Name: review_reason; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.review_reason AS ENUM (
    'VALOR_ACIMA_DO_MERCADO',
    'FALTA_DETALHAMENTO_TECNICO',
    'PRESTADOR_COM_RESTRICAO',
    'DOCUMENTACAO_INCOMPLETA',
    'OUTROS'
);


ALTER TYPE nfe_vigia.review_reason OWNER TO postgres;

--
-- Name: stock_move_type; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.stock_move_type AS ENUM (
    'ENTRADA',
    'SAIDA',
    'AJUSTE'
);


ALTER TYPE nfe_vigia.stock_move_type OWNER TO postgres;

--
-- Name: subscription_status; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.subscription_status AS ENUM (
    'ATIVO',
    'CANCELADO'
);


ALTER TYPE nfe_vigia.subscription_status OWNER TO postgres;

--
-- Name: ticket_status; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.ticket_status AS ENUM (
    'ABERTO',
    'REJEITADO',
    'APROVADO',
    'CANCELADO'
);


ALTER TYPE nfe_vigia.ticket_status OWNER TO postgres;

--
-- Name: user_profile; Type: TYPE; Schema: nfe_vigia; Owner: postgres
--

CREATE TYPE nfe_vigia.user_profile AS ENUM (
    'MORADOR',
    'ZELADOR',
    'SINDICO',
    'SUBSINDICO',
    'CONSELHO',
    'ADMIN'
);


ALTER TYPE nfe_vigia.user_profile OWNER TO postgres;

--
-- Name: can_finalize_service_order(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.can_finalize_service_order(p_service_order_id uuid) RETURNS boolean
    LANGUAGE plpgsql
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
declare
  v_sub_ok boolean;
  v_conselho_ok boolean;
  v_sindico_ok boolean;
begin
  select exists (
    select 1
    from nfe_vigia.service_order_approvals
    where service_order_id = p_service_order_id
      and approver_role = 'SUB_SINDICO'
      and response_status in ('APROVADA','RECUSADA','NEUTRO')
  ) into v_sub_ok;

  select exists (
    select 1
    from nfe_vigia.service_order_approvals
    where service_order_id = p_service_order_id
      and approver_role = 'CONSELHO_FISCAL'
      and response_status in ('APROVADA','RECUSADA','NEUTRO')
  ) into v_conselho_ok;

  select exists (
    select 1
    from nfe_vigia.service_order_approvals
    where service_order_id = p_service_order_id
      and approver_role = 'SINDICO'
      and response_status in ('APROVADA','RECUSADA')
  ) into v_sindico_ok;

  return v_sub_ok and v_conselho_ok and v_sindico_ok;
end;
$$;


ALTER FUNCTION nfe_vigia.can_finalize_service_order(p_service_order_id uuid) OWNER TO postgres;

--
-- Name: create_default_approval_policy_for_new_condo(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.create_default_approval_policy_for_new_condo() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
begin
  insert into nfe_vigia.condo_approval_policies (
    condo_id,
    policy_type,
    use_amount_limit,
    require_sindico,
    require_sub_sindico,
    require_conselho_fiscal,
    decision_mode,
    syndic_tiebreaker,
    active
  )
  values (
    new.id,
    'NF',
    false,
    true,
    true,
    true,
    'MAIORIA',
    true,
    true
  );

  return new;
end;
$$;


ALTER FUNCTION nfe_vigia.create_default_approval_policy_for_new_condo() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auth_user_id uuid NOT NULL,
    condo_id uuid,
    full_name text NOT NULL,
    email nfe_vigia.citext NOT NULL,
    profile nfe_vigia.user_profile NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    status text DEFAULT 'ativo'::text,
    cpf_rg text,
    birth_date date,
    residence_type text,
    CONSTRAINT users_residence_type_check CHECK ((residence_type = ANY (ARRAY['apartamento'::text, 'casa'::text]))),
    CONSTRAINT users_status_check CHECK ((status = ANY (ARRAY['ativo'::text, 'pendente'::text, 'recusado'::text, 'inativo'::text])))
);


ALTER TABLE nfe_vigia.users OWNER TO postgres;

--
-- Name: current_app_user(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.current_app_user() RETURNS nfe_vigia.users
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select u.*
  from nfe_vigia.users u
  where u.auth_user_id = auth.uid()
    and u.deleted_at is null
  limit 1
$$;


ALTER FUNCTION nfe_vigia.current_app_user() OWNER TO postgres;

--
-- Name: current_condo_id(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.current_condo_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select (current_app_user()).condo_id
$$;


ALTER FUNCTION nfe_vigia.current_condo_id() OWNER TO postgres;

--
-- Name: current_condo_id_v2(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.current_condo_id_v2() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select uc.condo_id
  from nfe_vigia.user_condos uc
  join nfe_vigia.users u
    on u.id = uc.user_id
  where u.auth_user_id = auth.uid()
    and uc.is_default = true
  limit 1;
$$;


ALTER FUNCTION nfe_vigia.current_condo_id_v2() OWNER TO postgres;

--
-- Name: current_profile(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.current_profile() RETURNS nfe_vigia.user_profile
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select (current_app_user()).profile
$$;


ALTER FUNCTION nfe_vigia.current_profile() OWNER TO postgres;

--
-- Name: current_role(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia."current_role"() RETURNS nfe_vigia.user_profile
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select uc.role
  from nfe_vigia.user_condos uc
  join nfe_vigia.users u
    on u.id = uc.user_id
  where u.auth_user_id = auth.uid()
    and uc.is_default = true
  limit 1;
$$;


ALTER FUNCTION nfe_vigia."current_role"() OWNER TO postgres;

--
-- Name: current_user_id(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.current_user_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select id
  from nfe_vigia.users
  where auth_user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION nfe_vigia.current_user_id() OWNER TO postgres;

--
-- Name: deactivate_user(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.deactivate_user(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
begin

  update nfe_vigia.users
  set
    is_active = false,
    updated_at = now()
  where id = p_user_id;

end;
$$;


ALTER FUNCTION nfe_vigia.deactivate_user(p_user_id uuid) OWNER TO postgres;

--
-- Name: get_active_condo_context(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_active_condo_context() RETURNS TABLE(condo_id uuid, condo_name text, role text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
select
  c.id as condo_id,
  c.name as condo_name,
  uc.role::text as role
from user_condos uc
join users u on u.id = uc.user_id
join condos c on c.id = uc.condo_id
where u.auth_user_id = auth.uid()
  and uc.is_default = true
limit 1;
$$;


ALTER FUNCTION nfe_vigia.get_active_condo_context() OWNER TO postgres;

--
-- Name: get_active_condo_id(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_active_condo_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
select condo_id
from user_condos
where user_id = auth.uid()
and is_default = true
limit 1;
$$;


ALTER FUNCTION nfe_vigia.get_active_condo_id() OWNER TO postgres;

--
-- Name: get_active_user_id(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_active_user_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select u.id
  from nfe_vigia.users u
  where u.auth_user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION nfe_vigia.get_active_user_id() OWNER TO postgres;

--
-- Name: get_my_condo_id(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_my_condo_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select uc.condo_id
  from nfe_vigia.user_condos uc
  join nfe_vigia.users u on u.id = uc.user_id
  where u.auth_user_id = auth.uid()
  order by uc.is_default desc, uc.created_at asc
  limit 1;
$$;


ALTER FUNCTION nfe_vigia.get_my_condo_id() OWNER TO postgres;

--
-- Name: get_my_condos(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_my_condos() RETURNS TABLE(condo_id uuid, condo_name text, role text, is_default boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
select
  c.id,
  c.name,
  uc.role::text,
  uc.is_default
from user_condos uc
join users u on u.id = uc.user_id
join condos c on c.id = uc.condo_id
where u.auth_user_id = auth.uid()
order by uc.is_default desc, c.name asc;
$$;


ALTER FUNCTION nfe_vigia.get_my_condos() OWNER TO postgres;

--
-- Name: get_user_condo_ids(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_user_condo_ids() RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT uc.condo_id 
  FROM nfe_vigia.user_condos uc
  JOIN nfe_vigia.users u ON u.id = uc.user_id
  WHERE u.auth_user_id = auth.uid()
$$;


ALTER FUNCTION nfe_vigia.get_user_condo_ids() OWNER TO postgres;

--
-- Name: get_user_condos(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_user_condos() RETURNS TABLE(condo_id uuid, condo_name text, role text, is_default boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
select 
  c.id,
  c.name,
  uc.role::text,
  uc.is_default
from user_condos uc
join condos c on c.id = uc.condo_id
where uc.user_id = auth.uid();
$$;


ALTER FUNCTION nfe_vigia.get_user_condos() OWNER TO postgres;

--
-- Name: get_user_role_in_condo(uuid, uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.get_user_role_in_condo(p_user_id uuid, p_condo_id uuid) RETURNS nfe_vigia.user_profile
    LANGUAGE sql STABLE
    AS $$
  select role
  from nfe_vigia.user_condos
  where user_id = p_user_id
  and condo_id = p_condo_id
  limit 1;
$$;


ALTER FUNCTION nfe_vigia.get_user_role_in_condo(p_user_id uuid, p_condo_id uuid) OWNER TO postgres;

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
begin
  insert into nfe_vigia.users (auth_user_id, email, full_name, profile)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', 'Usuário'),
    'ADMIN'::nfe_vigia.user_profile
  )
  on conflict (auth_user_id) do update
    set email = excluded.email;

  return new;
end;
$$;


ALTER FUNCTION nfe_vigia.handle_new_user() OWNER TO postgres;

--
-- Name: is_current_user_active(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.is_current_user_active() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select coalesce((
    select u.is_active
    from nfe_vigia.users u
    where u.auth_user_id = auth.uid()
    limit 1
  ), false);
$$;


ALTER FUNCTION nfe_vigia.is_current_user_active() OWNER TO postgres;

--
-- Name: is_current_user_sindico(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.is_current_user_sindico() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select exists (
    select 1
    from nfe_vigia.user_condos uc
    join nfe_vigia.users u on u.id = uc.user_id
    where u.auth_user_id = auth.uid()
      and uc.condo_id = nfe_vigia.get_my_condo_id()
      and uc.role = 'SINDICO'::nfe_vigia.user_profile
  );
$$;


ALTER FUNCTION nfe_vigia.is_current_user_sindico() OWNER TO postgres;

--
-- Name: is_current_user_sindico_aal2(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.is_current_user_sindico_aal2() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select
    nfe_vigia.is_current_user_sindico()
    and coalesce((select auth.jwt()->>'aal'), 'aal1') = 'aal2';
$$;


ALTER FUNCTION nfe_vigia.is_current_user_sindico_aal2() OWNER TO postgres;

--
-- Name: is_sindico_in_condo(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.is_sindico_in_condo(p_condo_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM nfe_vigia.user_condos uc
    JOIN nfe_vigia.users u ON u.id = uc.user_id
    WHERE u.auth_user_id = auth.uid()
    AND uc.condo_id = p_condo_id
    AND uc.role IN ('SINDICO', 'ADMIN')
  );
$$;


ALTER FUNCTION nfe_vigia.is_sindico_in_condo(p_condo_id uuid) OWNER TO postgres;

--
-- Name: list_pending_approvals(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.list_pending_approvals(p_condo_id uuid) RETURNS TABLE(user_id uuid, full_name text, email text, cpf_rg text, birth_date date, created_at timestamp with time zone, block text, unit text, unit_label text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
  SELECT
    u.id AS user_id,
    u.full_name,
    u.email,
    u.cpf_rg,
    u.birth_date,
    u.created_at,
    r.block,
    r.unit,
    r.unit_label
  FROM nfe_vigia.user_condos uc
  JOIN nfe_vigia.users u ON u.id = uc.user_id
  LEFT JOIN nfe_vigia.residents r ON lower(r.email) = lower(u.email) 
    AND r.condo_id = uc.condo_id
  WHERE uc.condo_id = p_condo_id
    AND uc.status = 'pendente'
  ORDER BY u.created_at ASC;
$$;


ALTER FUNCTION nfe_vigia.list_pending_approvals(p_condo_id uuid) OWNER TO postgres;

--
-- Name: list_residents_with_user_match(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.list_residents_with_user_match() RETURNS TABLE(resident_id uuid, condo_id uuid, unit_id uuid, full_name text, email text, phone text, unit_label text, block text, unit text, matched_user_id uuid, matched_user_email text, matched_role nfe_vigia.user_profile)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select
    r.id as resident_id,
    r.condo_id,
    r.unit_id,
    r.full_name,
    r.email,
    r.phone,
    r.unit_label,
    r.block,
    r.unit,
    u.id as matched_user_id,
    u.email as matched_user_email,
    uc.role as matched_role
  from nfe_vigia.residents r
  left join nfe_vigia.users u
    on lower(trim(u.email::text)) = lower(trim(r.email))
  left join nfe_vigia.user_condos uc
    on uc.user_id = u.id
   and uc.condo_id = r.condo_id
   and uc.is_default = true
  where r.condo_id = nfe_vigia.current_condo_id_v2()
  order by r.full_name;
$$;


ALTER FUNCTION nfe_vigia.list_residents_with_user_match() OWNER TO postgres;

--
-- Name: list_residents_with_user_match(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.list_residents_with_user_match(_condo_id uuid) RETURNS TABLE(resident_id uuid, condo_id uuid, block text, unit text, unit_label text, full_name text, email text, phone text, matched_user_id uuid, matched_user_email text, matched_role text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
  SELECT
    r.id          AS resident_id,
    r.condo_id,
    r.block,
    r.unit,
    r.unit_label,
    r.full_name,
    r.email,
    r.phone,
    u.id          AS matched_user_id,
    u.email       AS matched_user_email,
    uc.role       AS matched_role
  FROM nfe_vigia.residents r
  LEFT JOIN nfe_vigia.users u
    ON lower(u.email) = lower(r.email)
  LEFT JOIN nfe_vigia.user_condos uc
    ON uc.user_id = u.id
   AND uc.condo_id = r.condo_id
  WHERE r.condo_id = _condo_id
  ORDER BY r.full_name;
$$;


ALTER FUNCTION nfe_vigia.list_residents_with_user_match(_condo_id uuid) OWNER TO postgres;

--
-- Name: mark_expired_service_order_approvals(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.mark_expired_service_order_approvals() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  update nfe_vigia.service_order_approvals
  set response_status = 'NEUTRO'
  where response_status = 'PENDENTE'
  and due_at is not null
  and due_at < now();
end;
$$;


ALTER FUNCTION nfe_vigia.mark_expired_service_order_approvals() OWNER TO postgres;

--
-- Name: onboard_create_condo(text, text); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.onboard_create_condo(p_name text, p_document text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
declare
  v_existing_condo uuid;
  v_new_condo uuid;
begin
  select condo_id
    into v_existing_condo
  from nfe_vigia.users
  where auth_user_id = auth.uid();

  if v_existing_condo is not null then
    return v_existing_condo;
  end if;

  insert into nfe_vigia.condos (name, document)
  values (p_name, nullif(p_document, ''))
  returning id into v_new_condo;

  update nfe_vigia.users
     set condo_id = v_new_condo
   where auth_user_id = auth.uid();

  return v_new_condo;
end;
$$;


ALTER FUNCTION nfe_vigia.onboard_create_condo(p_name text, p_document text) OWNER TO postgres;

--
-- Name: set_active_condo(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.set_active_condo(p_condo_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
declare
  v_user_id uuid;
begin
  select id
  into v_user_id
  from users
  where auth_user_id = auth.uid()
  limit 1;

  update user_condos
  set is_default = false
  where user_id = v_user_id;

  update user_condos
  set is_default = true
  where user_id = v_user_id
    and condo_id = p_condo_id;
end;
$$;


ALTER FUNCTION nfe_vigia.set_active_condo(p_condo_id uuid) OWNER TO postgres;

--
-- Name: set_approvals_defaults(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.set_approvals_defaults() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Preenche actor_user_id com approver_id se não informado
  IF NEW.actor_user_id IS NULL AND NEW.approver_id IS NOT NULL THEN
    NEW.actor_user_id = NEW.approver_id;
  END IF;
  
  -- Preenche approver_id com actor_user_id se não informado
  IF NEW.approver_id IS NULL AND NEW.actor_user_id IS NOT NULL THEN
    NEW.approver_id = NEW.actor_user_id;
  END IF;
  
  -- Define decision padrão
  IF NEW.decision IS NULL THEN
    NEW.decision = 'pendente';
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION nfe_vigia.set_approvals_defaults() OWNER TO postgres;

--
-- Name: set_moved_by_user_id(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.set_moved_by_user_id() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.moved_by_user_id IS NULL THEN
    SELECT id INTO NEW.moved_by_user_id
    FROM nfe_vigia.users
    WHERE auth_user_id = auth.uid()
    AND deleted_at IS NULL
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION nfe_vigia.set_moved_by_user_id() OWNER TO postgres;

--
-- Name: set_service_order_approval_responded_at(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.set_service_order_approval_responded_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.response_status in ('APROVADA','RECUSADA','NEUTRO') then
    new.responded_at := now();
  end if;

  return new;
end;
$$;


ALTER FUNCTION nfe_vigia.set_service_order_approval_responded_at() OWNER TO postgres;

--
-- Name: subscription_is_cancelled(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.subscription_is_cancelled() RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
  select coalesce((
    select (s.status = 'CANCELADO')
    from nfe_vigia.subscriptions s
    where s.condo_id = nfe_vigia.current_condo_id_v2()
      and s.deleted_at is null
    order by s.created_at desc
    limit 1
  ), false)
$$;


ALTER FUNCTION nfe_vigia.subscription_is_cancelled() OWNER TO postgres;

--
-- Name: switch_active_condo(uuid); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.switch_active_condo(p_condo_id uuid) RETURNS TABLE(out_condo_id uuid, out_condo_name text, out_role text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
declare
  v_user_id uuid;
begin
  select id into v_user_id
  from users
  where auth_user_id = auth.uid()
  limit 1;

  update user_condos
  set is_default = false
  where user_id = v_user_id;

  update user_condos
  set is_default = true
  where user_id = v_user_id
    and user_condos.condo_id = p_condo_id;

  return query
  select
    c.id as out_condo_id,
    c.name as out_condo_name,
    uc.role::text as out_role
  from user_condos uc
  join condos c on c.id = uc.condo_id
  where uc.user_id = v_user_id
    and uc.condo_id = p_condo_id
  limit 1;
end;
$$;


ALTER FUNCTION nfe_vigia.switch_active_condo(p_condo_id uuid) OWNER TO postgres;

--
-- Name: sync_users_condo_id_from_user_condos(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.sync_users_condo_id_from_user_condos() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
begin
  if new.is_default = true then
    update nfe_vigia.users
    set condo_id = new.condo_id
    where id = new.user_id;
  end if;

  return new;
end;
$$;


ALTER FUNCTION nfe_vigia.sync_users_condo_id_from_user_condos() OWNER TO postgres;

--
-- Name: tg_enforce_3_budgets_for_standard(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.tg_enforce_3_budgets_for_standard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare c int;
begin
  if new.status = 'AGUARDANDO_APROVACAO' and new.os_type = 'PADRAO' then
    select count(*) into c
    from budgets
    where work_order_id = new.id
      and condo_id = new.condo_id
      and deleted_at is null;
    if c < 3 then
      raise exception 'OS padrão exige no mínimo 3 orçamentos antes da aprovação';
    end if;
  end if;
  return new;
end $$;


ALTER FUNCTION nfe_vigia.tg_enforce_3_budgets_for_standard() OWNER TO postgres;

--
-- Name: tg_on_approval_apply_state(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.tg_on_approval_apply_state() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare v_provider uuid;
begin
  if new.action = 'APROVAR' then
    select provider_id into v_provider
    from budgets
    where id = new.approved_budget_id
      and condo_id = new.condo_id
      and deleted_at is null;

    if v_provider is null then
      raise exception 'Orçamento aprovado inválido';
    end if;

    update work_orders
    set status='APROVADA',
        provider_id=v_provider,
        updated_at=now()
    where id=new.work_order_id and condo_id=new.condo_id;

  else
    update work_orders
    set status='EM_COTACAO', updated_at=now()
    where id=new.work_order_id and condo_id=new.condo_id;
  end if;

  return new;
end $$;


ALTER FUNCTION nfe_vigia.tg_on_approval_apply_state() OWNER TO postgres;

--
-- Name: tg_set_updated_at(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.tg_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  return new;
end $$;


ALTER FUNCTION nfe_vigia.tg_set_updated_at() OWNER TO postgres;

--
-- Name: tg_validate_work_order_classification(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.tg_validate_work_order_classification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.os_type = 'EMERGENCIAL' then
    new.is_emergency := true;
    if new.emergency_justification is null or length(trim(new.emergency_justification)) = 0 then
      raise exception 'Justificativa obrigatória para OS emergencial';
    end if;
  elsif new.os_type = 'PADRAO' then
    new.is_emergency := false;
    new.emergency_justification := null;
  end if;
  return new;
end $$;


ALTER FUNCTION nfe_vigia.tg_validate_work_order_classification() OWNER TO postgres;

--
-- Name: transfer_sindico_role(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.transfer_sindico_role(p_old_user_id uuid, p_new_user_id uuid, p_condo_id uuid, p_deactivate_old boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia', 'public'
    AS $$
declare
  v_changed_by uuid;
begin

  -- descobrir qual usuário está executando a ação
  select id
  into v_changed_by
  from nfe_vigia.users
  where auth_user_id = auth.uid()
  limit 1;

  -- remover papel de síndico do antigo
  update nfe_vigia.user_condos
  set role = 'MORADOR'::nfe_vigia.user_profile
  where user_id = p_old_user_id
    and condo_id = p_condo_id
    and role = 'SINDICO'::nfe_vigia.user_profile;

  -- promover novo síndico
  update nfe_vigia.user_condos
  set role = 'SINDICO'::nfe_vigia.user_profile
  where user_id = p_new_user_id
    and condo_id = p_condo_id;

  -- desativar síndico antigo (opcional)
  if p_deactivate_old then
    update nfe_vigia.users
    set
      is_active = false,
      updated_at = now()
    where id = p_old_user_id;
  end if;

  -- registrar auditoria da troca
  insert into nfe_vigia.sindico_transfer_logs (
    condo_id,
    old_user_id,
    new_user_id,
    changed_by,
    old_role,
    new_role,
    old_user_deactivated
  )
  values (
    p_condo_id,
    p_old_user_id,
    p_new_user_id,
    v_changed_by,
    'SINDICO',
    'SINDICO',
    p_deactivate_old
  );

end;
$$;


ALTER FUNCTION nfe_vigia.transfer_sindico_role(p_old_user_id uuid, p_new_user_id uuid, p_condo_id uuid, p_deactivate_old boolean) OWNER TO postgres;

--
-- Name: update_fiscal_document_status(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.update_fiscal_document_status() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  total_approvals INT;
  approved_count INT;
  rejected_count INT;
BEGIN
  SELECT COUNT(*) INTO total_approvals
  FROM nfe_vigia.fiscal_document_approvals
  WHERE fiscal_document_id = NEW.fiscal_document_id;

  SELECT COUNT(*) INTO approved_count
  FROM nfe_vigia.fiscal_document_approvals
  WHERE fiscal_document_id = NEW.fiscal_document_id
  AND decision = 'aprovado';

  SELECT COUNT(*) INTO rejected_count
  FROM nfe_vigia.fiscal_document_approvals
  WHERE fiscal_document_id = NEW.fiscal_document_id
  AND decision = 'rejeitado';

  IF rejected_count > 0 THEN
    UPDATE nfe_vigia.fiscal_documents
    SET approval_status = 'rejeitado'
    WHERE id = NEW.fiscal_document_id;

  ELSIF approved_count = total_approvals AND total_approvals > 0 THEN
    UPDATE nfe_vigia.fiscal_documents
    SET approval_status = 'aprovado'
    WHERE id = NEW.fiscal_document_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION nfe_vigia.update_fiscal_document_status() OWNER TO postgres;

--
-- Name: update_user_role(uuid, uuid, text); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.update_user_role(_target_user_id uuid, _condo_id uuid, _new_role text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'nfe_vigia'
    AS $$
DECLARE
  _caller_internal_id uuid;
  _caller_role text;
BEGIN
  SELECT id INTO _caller_internal_id
  FROM nfe_vigia.users
  WHERE auth_user_id = auth.uid();

  IF _caller_internal_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado';
  END IF;

  SELECT role::text INTO _caller_role
  FROM nfe_vigia.user_condos
  WHERE user_id = _caller_internal_id
    AND condo_id = _condo_id;

  IF _caller_role NOT IN ('SINDICO', 'ADMIN') THEN
    RAISE EXCEPTION 'Sem permissão para alterar funções';
  END IF;

  UPDATE nfe_vigia.user_condos
  SET role = _new_role::user_profile
  WHERE user_id = _target_user_id
    AND condo_id = _condo_id;

  UPDATE nfe_vigia.users
  SET profile = _new_role::user_profile
  WHERE id = _target_user_id;
END;
$$;


ALTER FUNCTION nfe_vigia.update_user_role(_target_user_id uuid, _condo_id uuid, _new_role text) OWNER TO postgres;

--
-- Name: validate_service_order_completion(); Type: FUNCTION; Schema: nfe_vigia; Owner: postgres
--

CREATE FUNCTION nfe_vigia.validate_service_order_completion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.status = 'FINALIZADA' then
    if not nfe_vigia.can_finalize_service_order(new.id) then
      raise exception 'Service order cannot be finalized yet. Approvals pending.';
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION nfe_vigia.validate_service_order_completion() OWNER TO postgres;

--
-- Name: approvals; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.approvals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    actor_user_id uuid NOT NULL,
    action nfe_vigia.approval_action,
    approved_budget_id uuid,
    review_reason nfe_vigia.review_reason,
    review_details text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    service_order_id uuid,
    budget_id uuid,
    approver_role text DEFAULT 'sindico'::text NOT NULL,
    decision text,
    responded_at timestamp with time zone,
    expires_at timestamp with time zone,
    is_minerva boolean DEFAULT false,
    minerva_justification text,
    approval_type text DEFAULT 'ORCAMENTO'::text NOT NULL,
    approver_id uuid,
    CONSTRAINT approvals_approver_role_check CHECK ((lower(approver_role) = ANY (ARRAY['sindico'::text, 'subsindico'::text, 'conselheiro_fiscal'::text, 'conselho'::text]))),
    CONSTRAINT approvals_decision_check CHECK ((decision = ANY (ARRAY['aprovado'::text, 'rejeitado'::text, 'pendente'::text])))
);


ALTER TABLE nfe_vigia.approvals OWNER TO postgres;

--
-- Name: audit_events; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.audit_events (
    id bigint NOT NULL,
    condo_id uuid NOT NULL,
    actor_user_id uuid,
    entity_type text NOT NULL,
    entity_id uuid,
    event_type text NOT NULL,
    event_at timestamp with time zone DEFAULT now() NOT NULL,
    details jsonb
);


ALTER TABLE nfe_vigia.audit_events OWNER TO postgres;

--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: nfe_vigia; Owner: postgres
--

CREATE SEQUENCE nfe_vigia.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe_vigia.audit_events_id_seq OWNER TO postgres;

--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe_vigia; Owner: postgres
--

ALTER SEQUENCE nfe_vigia.audit_events_id_seq OWNED BY nfe_vigia.audit_events.id;


--
-- Name: budgets; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.budgets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    amount_cents bigint,
    file_id uuid,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    service_order_id uuid,
    status text DEFAULT 'pendente'::text NOT NULL,
    description text,
    valid_until date,
    alcada_nivel integer DEFAULT 1,
    total_value numeric(10,2),
    expires_at timestamp with time zone,
    CONSTRAINT budgets_amount_cents_check CHECK (((amount_cents IS NULL) OR (amount_cents >= 0))),
    CONSTRAINT budgets_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'aprovado'::text, 'rejeitado'::text])))
);


ALTER TABLE nfe_vigia.budgets OWNER TO postgres;

--
-- Name: chamados; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.chamados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    titulo text NOT NULL,
    descricao text,
    unidade text,
    bloco text,
    status text DEFAULT 'pendente_triagem'::text NOT NULL,
    criado_por uuid,
    condominio_id uuid,
    service_order_id uuid,
    close_reason text,
    prioridade text DEFAULT 'media'::text NOT NULL,
    categoria text,
    tipo_execucao text,
    emergencial boolean DEFAULT false NOT NULL,
    motivo_cancelamento text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chamados_prioridade_check CHECK ((prioridade = ANY (ARRAY['baixa'::text, 'media'::text, 'alta'::text, 'urgente'::text]))),
    CONSTRAINT chamados_tipo_execucao_check CHECK (((tipo_execucao IS NULL) OR (tipo_execucao = ANY (ARRAY['interno'::text, 'externo'::text]))))
);


ALTER TABLE nfe_vigia.chamados OWNER TO postgres;

--
-- Name: condo_approval_policies; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.condo_approval_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    policy_type text NOT NULL,
    use_amount_limit boolean DEFAULT false NOT NULL,
    min_amount numeric(14,2),
    max_amount numeric(14,2),
    require_sindico boolean DEFAULT true NOT NULL,
    require_sub_sindico boolean DEFAULT false NOT NULL,
    require_conselho_fiscal boolean DEFAULT false NOT NULL,
    decision_mode text DEFAULT 'MAIORIA'::text NOT NULL,
    syndic_tiebreaker boolean DEFAULT true NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT condo_approval_policies_decision_mode_check CHECK ((decision_mode = ANY (ARRAY['MAIORIA'::text, 'UNANIME'::text]))),
    CONSTRAINT condo_approval_policies_policy_type_check CHECK ((policy_type = ANY (ARRAY['OS'::text, 'NF'::text, 'AMBOS'::text])))
);


ALTER TABLE nfe_vigia.condo_approval_policies OWNER TO postgres;

--
-- Name: condo_financial_config; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.condo_financial_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    alcada_1_limite numeric(10,2) DEFAULT 500.00,
    alcada_2_limite numeric(10,2) DEFAULT 2000.00,
    alcada_3_limite numeric(10,2) DEFAULT 10000.00,
    approval_deadline_hours integer DEFAULT 48,
    notify_residents_above numeric(10,2) DEFAULT 10000.00,
    monthly_limit_manutencao numeric(10,2),
    monthly_limit_limpeza numeric(10,2),
    monthly_limit_seguranca numeric(10,2),
    annual_budget numeric(10,2),
    annual_budget_alert_pct integer DEFAULT 70,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    monthly_budget numeric(12,2)
);


ALTER TABLE nfe_vigia.condo_financial_config OWNER TO postgres;

--
-- Name: condos; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.condos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    document text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    invite_code text,
    invite_active boolean DEFAULT false,
    subscription_status text DEFAULT 'trial'::text NOT NULL,
    subscription_id text,
    subscription_expires_at timestamp with time zone,
    pagarme_customer_id text
);


ALTER TABLE nfe_vigia.condos OWNER TO postgres;

--
-- Name: COLUMN condos.subscription_status; Type: COMMENT; Schema: nfe_vigia; Owner: postgres
--

COMMENT ON COLUMN nfe_vigia.condos.subscription_status IS 'trial = within free trial, active = paid and current, past_due = payment failed, canceled = no longer subscribed';


--
-- Name: contracts; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.contracts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    provider_id uuid,
    title text NOT NULL,
    description text,
    contract_type text DEFAULT 'OUTROS'::text NOT NULL,
    value numeric(12,2),
    start_date date,
    end_date date,
    file_url text,
    status text DEFAULT 'RASCUNHO'::text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE nfe_vigia.contracts OWNER TO postgres;

--
-- Name: dossiers; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.dossiers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    work_order_id uuid NOT NULL,
    file_id uuid NOT NULL,
    hash_algorithm text DEFAULT 'SHA-256'::text NOT NULL,
    hash_hex text NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    generated_by_user_id uuid NOT NULL
);


ALTER TABLE nfe_vigia.dossiers OWNER TO postgres;

--
-- Name: files; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    kind nfe_vigia.file_kind NOT NULL,
    storage_key text NOT NULL,
    file_name text NOT NULL,
    content_type text NOT NULL,
    size_bytes bigint NOT NULL,
    sha256_hex text,
    created_by_user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT files_size_bytes_check CHECK ((size_bytes >= 0))
);


ALTER TABLE nfe_vigia.files OWNER TO postgres;

--
-- Name: fiscal_document_approvals; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.fiscal_document_approvals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    fiscal_document_id uuid NOT NULL,
    approver_user_id uuid NOT NULL,
    approver_role text NOT NULL,
    decision text,
    justification text,
    voted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    is_minerva boolean DEFAULT false,
    minerva_justification text,
    CONSTRAINT fiscal_document_approvals_approver_role_check CHECK ((approver_role = ANY (ARRAY['SUBSINDICO'::text, 'CONSELHO'::text, 'SINDICO'::text]))),
    CONSTRAINT fiscal_document_approvals_decision_check CHECK ((decision = ANY (ARRAY['aprovado'::text, 'rejeitado'::text, 'pendente'::text])))
);


ALTER TABLE nfe_vigia.fiscal_document_approvals OWNER TO postgres;

--
-- Name: fiscal_document_items; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.fiscal_document_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fiscal_document_id uuid NOT NULL,
    stock_item_id uuid,
    qty numeric NOT NULL,
    unit_price numeric DEFAULT 0 NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT fiscal_document_items_qty_check CHECK ((qty > (0)::numeric))
);


ALTER TABLE nfe_vigia.fiscal_document_items OWNER TO postgres;

--
-- Name: fiscal_documents; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.fiscal_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    created_by uuid,
    document_type text DEFAULT 'NF'::text NOT NULL,
    source_type text NOT NULL,
    issuer_name text,
    issuer_document text,
    taker_name text,
    taker_document text,
    document_number text,
    series text,
    verification_code text,
    issue_date timestamp with time zone,
    service_city text,
    service_state text,
    gross_amount numeric(14,2),
    net_amount numeric(14,2),
    tax_amount numeric(14,2),
    status text DEFAULT 'PENDENTE'::text NOT NULL,
    access_key text,
    file_url text,
    raw_payload jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    service_order_id uuid,
    approval_status text DEFAULT 'pendente'::text NOT NULL,
    approved_by_subsindico uuid,
    approved_by_subsindico_at timestamp with time zone,
    sindico_voto_minerva boolean DEFAULT false,
    sindico_voto_at timestamp with time zone,
    alcada_nivel integer DEFAULT 1,
    notify_residents boolean DEFAULT false,
    amount numeric(10,2),
    supplier text,
    number text,
    CONSTRAINT fiscal_documents_approval_status_check CHECK ((approval_status = ANY (ARRAY['pendente'::text, 'aprovado'::text, 'rejeitado'::text]))),
    CONSTRAINT fiscal_documents_document_type_check CHECK ((document_type = ANY (ARRAY['NFE'::text, 'NFSE'::text, 'COMPROVANTE'::text]))),
    CONSTRAINT fiscal_documents_source_type_check CHECK ((source_type = ANY (ARRAY['SEFAZ'::text, 'MUNICIPIO'::text, 'UPLOAD'::text, 'EMAIL'::text, 'MANUAL'::text]))),
    CONSTRAINT fiscal_documents_status_check CHECK ((status = ANY (ARRAY['PENDENTE'::text, 'PROCESSADO'::text, 'CANCELADO'::text, 'ERRO'::text])))
);


ALTER TABLE nfe_vigia.fiscal_documents OWNER TO postgres;

--
-- Name: invoices; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    invoice_type nfe_vigia.invoice_type NOT NULL,
    work_order_id uuid,
    provider_id uuid,
    invoice_number text,
    invoice_key text,
    issued_at date,
    amount_cents bigint,
    file_id uuid,
    created_by_user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT invoices_amount_cents_check CHECK (((amount_cents IS NULL) OR (amount_cents >= 0)))
);


ALTER TABLE nfe_vigia.invoices OWNER TO postgres;

--
-- Name: provider_risk_analysis; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.provider_risk_analysis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_id uuid,
    condo_id uuid,
    score integer,
    nivel_risco text,
    situacao_receita text,
    possui_protestos boolean DEFAULT false,
    possui_processos boolean DEFAULT false,
    noticias_negativas boolean DEFAULT false,
    historico_interno text,
    recomendacao text,
    relatorio_completo text,
    consultado_em timestamp with time zone DEFAULT now(),
    consultado_por uuid,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT provider_risk_analysis_nivel_risco_check CHECK ((nivel_risco = ANY (ARRAY['BAIXO'::text, 'MEDIO'::text, 'ALTO'::text, 'CRITICO'::text]))),
    CONSTRAINT provider_risk_analysis_recomendacao_check CHECK ((recomendacao = ANY (ARRAY['APROVADO'::text, 'ATENCAO'::text, 'REPROVADO'::text]))),
    CONSTRAINT provider_risk_analysis_score_check CHECK (((score >= 0) AND (score <= 100)))
);


ALTER TABLE nfe_vigia.provider_risk_analysis OWNER TO postgres;

--
-- Name: providers; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    legal_name text NOT NULL,
    trade_name text,
    document text,
    email nfe_vigia.citext,
    phone text,
    has_restriction boolean DEFAULT false NOT NULL,
    restriction_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    address text,
    neighborhood text,
    zip_code text,
    website text,
    legal_nature text,
    share_capital numeric(15,2),
    company_size text,
    opening_date date,
    main_activity text,
    risk_score integer,
    risk_level text,
    tipo_servico text,
    status text DEFAULT 'ativo'::text,
    observacoes text,
    cidade text,
    estado text,
    CONSTRAINT providers_status_check CHECK ((status = ANY (ARRAY['ativo'::text, 'inativo'::text, 'bloqueado'::text])))
);


ALTER TABLE nfe_vigia.providers OWNER TO postgres;

--
-- Name: residents; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.residents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    unit_id uuid,
    full_name text NOT NULL,
    document text,
    email text,
    phone text,
    created_at timestamp with time zone DEFAULT now(),
    unit_label text,
    block text,
    unit text,
    residence_type text,
    tower_block text,
    apartment_number text,
    street text,
    street_number text,
    complement text,
    cpf_rg text,
    birth_date date,
    CONSTRAINT residents_residence_type_check CHECK ((residence_type = ANY (ARRAY['apartamento'::text, 'casa'::text])))
);


ALTER TABLE nfe_vigia.residents OWNER TO postgres;

--
-- Name: service_order_activities; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    user_id uuid,
    activity_type text NOT NULL,
    description text,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE nfe_vigia.service_order_activities OWNER TO postgres;

--
-- Name: service_order_approvals; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_approvals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    approved_by uuid NOT NULL,
    approver_role text NOT NULL,
    decision text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    response_status text DEFAULT 'PENDENTE'::text NOT NULL,
    due_at timestamp with time zone,
    responded_at timestamp with time zone,
    justification text,
    approval_type text DEFAULT 'ORCAMENTO'::text NOT NULL,
    CONSTRAINT service_order_approvals_approver_role_check CHECK ((approver_role = ANY (ARRAY['SUB_SINDICO'::text, 'CONSELHO_FISCAL'::text, 'SINDICO'::text]))),
    CONSTRAINT service_order_approvals_decision_check CHECK ((decision = ANY (ARRAY['APROVADA'::text, 'RECUSADA'::text]))),
    CONSTRAINT service_order_approvals_recusa_justificada_chk CHECK ((NOT ((response_status = 'RECUSADA'::text) AND ((justification IS NULL) OR (btrim(justification) = ''::text))))),
    CONSTRAINT service_order_approvals_response_status_check CHECK ((response_status = ANY (ARRAY['PENDENTE'::text, 'APROVADA'::text, 'RECUSADA'::text, 'NEUTRO'::text])))
);


ALTER TABLE nfe_vigia.service_order_approvals OWNER TO postgres;

--
-- Name: service_order_documents; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    fiscal_document_id uuid NOT NULL,
    document_kind text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT service_order_documents_document_kind_check CHECK ((document_kind = ANY (ARRAY['NF'::text, 'COMPROVANTE'::text])))
);


ALTER TABLE nfe_vigia.service_order_documents OWNER TO postgres;

--
-- Name: service_order_materials; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    stock_item_id uuid NOT NULL,
    quantity numeric NOT NULL,
    unit text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE nfe_vigia.service_order_materials OWNER TO postgres;

--
-- Name: service_order_photos; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    photo_type text NOT NULL,
    file_url text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    observation text,
    CONSTRAINT service_order_photos_photo_type_check CHECK ((photo_type = ANY (ARRAY['PROBLEMA'::text, 'FINAL'::text])))
);


ALTER TABLE nfe_vigia.service_order_photos OWNER TO postgres;

--
-- Name: service_order_quotes; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_quotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    provider_name text NOT NULL,
    value numeric(12,2) NOT NULL,
    description text,
    file_url text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE nfe_vigia.service_order_quotes OWNER TO postgres;

--
-- Name: service_order_votes; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_order_votes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_order_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    vote text NOT NULL,
    justification text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT service_order_votes_role_check CHECK ((role = ANY (ARRAY['SINDICO'::text, 'SUBSINDICO'::text, 'CONSELHO'::text]))),
    CONSTRAINT service_order_votes_vote_check CHECK ((vote = ANY (ARRAY['APROVAR'::text, 'RECUSAR'::text, 'RECOMENDAR_APROVACAO'::text, 'RECOMENDAR_RECUSA'::text])))
);


ALTER TABLE nfe_vigia.service_order_votes OWNER TO postgres;

--
-- Name: service_orders; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.service_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    created_by uuid NOT NULL,
    title text NOT NULL,
    description text,
    location text,
    status text DEFAULT 'ABERTA'::text NOT NULL,
    executor_type text,
    executor_name text,
    execution_notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    priority text DEFAULT 'MEDIA'::text NOT NULL,
    is_emergency boolean DEFAULT false NOT NULL,
    emergency_justification text,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    provider_id uuid,
    os_number bigint NOT NULL,
    final_pdf_url text,
    chamado_id uuid,
    CONSTRAINT service_orders_priority_check CHECK ((priority = ANY (ARRAY['BAIXA'::text, 'MEDIA'::text, 'ALTA'::text, 'URGENTE'::text]))),
    CONSTRAINT service_orders_status_check CHECK ((status = ANY (ARRAY['ABERTA'::text, 'EM_ANDAMENTO'::text, 'CONCLUIDA'::text, 'CANCELADA'::text, 'AGUARDANDO_ORCAMENTO'::text, 'AGUARDANDO_APROVACAO'::text, 'APROVADA'::text, 'RECUSADA'::text])))
);


ALTER TABLE nfe_vigia.service_orders OWNER TO postgres;

--
-- Name: service_orders_os_number_seq; Type: SEQUENCE; Schema: nfe_vigia; Owner: postgres
--

CREATE SEQUENCE nfe_vigia.service_orders_os_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe_vigia.service_orders_os_number_seq OWNER TO postgres;

--
-- Name: service_orders_os_number_seq; Type: SEQUENCE OWNED BY; Schema: nfe_vigia; Owner: postgres
--

ALTER SEQUENCE nfe_vigia.service_orders_os_number_seq OWNED BY nfe_vigia.service_orders.os_number;


--
-- Name: sindico_transfer_logs; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.sindico_transfer_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    old_user_id uuid NOT NULL,
    new_user_id uuid NOT NULL,
    changed_by uuid,
    old_role nfe_vigia.user_profile,
    new_role nfe_vigia.user_profile,
    old_user_deactivated boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE nfe_vigia.sindico_transfer_logs OWNER TO postgres;

--
-- Name: stock_categories; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.stock_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE nfe_vigia.stock_categories OWNER TO postgres;

--
-- Name: stock_items; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.stock_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    name text NOT NULL,
    unit text DEFAULT 'UN'::text NOT NULL,
    min_qty numeric(18,3) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    category_id uuid,
    description text
);


ALTER TABLE nfe_vigia.stock_items OWNER TO postgres;

--
-- Name: stock_movements; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.stock_movements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    item_id uuid NOT NULL,
    move_type nfe_vigia.stock_move_type NOT NULL,
    qty numeric(18,3) NOT NULL,
    unit_cost_cents bigint,
    supplier_name text,
    note text,
    moved_by_user_id uuid NOT NULL,
    moved_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    destination text,
    service_order_id uuid,
    fiscal_document_id uuid,
    CONSTRAINT stock_movements_destination_check CHECK ((destination = ANY (ARRAY['obra_aberta'::text, 'em_espera'::text, 'almoxarifado'::text]))),
    CONSTRAINT stock_movements_qty_check CHECK ((qty > (0)::numeric)),
    CONSTRAINT stock_movements_unit_cost_cents_check CHECK (((unit_cost_cents IS NULL) OR (unit_cost_cents >= 0)))
);


ALTER TABLE nfe_vigia.stock_movements OWNER TO postgres;

--
-- Name: subscriptions; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    provider text DEFAULT 'ASAAS'::text NOT NULL,
    external_customer_id text,
    external_subscription_id text,
    status nfe_vigia.subscription_status DEFAULT 'ATIVO'::nfe_vigia.subscription_status NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE nfe_vigia.subscriptions OWNER TO postgres;

--
-- Name: ticket_files; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.ticket_files (
    ticket_id uuid NOT NULL,
    file_id uuid NOT NULL
);


ALTER TABLE nfe_vigia.ticket_files OWNER TO postgres;

--
-- Name: tickets; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    opened_by_user_id uuid NOT NULL,
    unit_id uuid,
    title text,
    description text NOT NULL,
    category text DEFAULT 'ELÉTRICA'::text NOT NULL,
    priority text DEFAULT 'Mídia'::text NOT NULL,
    status nfe_vigia.ticket_status DEFAULT 'ABERTO'::nfe_vigia.ticket_status NOT NULL,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE nfe_vigia.tickets OWNER TO postgres;

--
-- Name: units; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    code text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE nfe_vigia.units OWNER TO postgres;

--
-- Name: user_condos; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.user_condos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    condo_id uuid NOT NULL,
    role nfe_vigia.user_profile DEFAULT 'MORADOR'::nfe_vigia.user_profile NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'ativo'::text,
    CONSTRAINT user_condos_status_check CHECK ((status = ANY (ARRAY['ativo'::text, 'pendente'::text, 'recusado'::text])))
);


ALTER TABLE nfe_vigia.user_condos OWNER TO postgres;

--
-- Name: user_sessions; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.user_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auth_user_id uuid NOT NULL,
    session_token text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE nfe_vigia.user_sessions OWNER TO postgres;

--
-- Name: user_units; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.user_units (
    user_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE nfe_vigia.user_units OWNER TO postgres;

--
-- Name: v_stock_balance; Type: VIEW; Schema: nfe_vigia; Owner: postgres
--

CREATE VIEW nfe_vigia.v_stock_balance AS
 SELECT condo_id,
    item_id,
    sum(
        CASE
            WHEN (move_type = 'ENTRADA'::nfe_vigia.stock_move_type) THEN qty
            WHEN (move_type = 'SAIDA'::nfe_vigia.stock_move_type) THEN (- qty)
            ELSE qty
        END) AS balance_qty
   FROM nfe_vigia.stock_movements
  GROUP BY condo_id, item_id;


ALTER VIEW nfe_vigia.v_stock_balance OWNER TO postgres;

--
-- Name: work_order_evidence; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.work_order_evidence (
    work_order_id uuid NOT NULL,
    file_id uuid NOT NULL,
    phase text NOT NULL,
    CONSTRAINT work_order_evidence_phase_check CHECK ((phase = ANY (ARRAY['ANTES'::text, 'DEPOIS'::text])))
);


ALTER TABLE nfe_vigia.work_order_evidence OWNER TO postgres;

--
-- Name: work_orders; Type: TABLE; Schema: nfe_vigia; Owner: postgres
--

CREATE TABLE nfe_vigia.work_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condo_id uuid NOT NULL,
    ticket_id uuid NOT NULL,
    created_by_user_id uuid NOT NULL,
    os_number bigint NOT NULL,
    os_type nfe_vigia.os_type,
    is_emergency boolean DEFAULT false NOT NULL,
    emergency_justification text,
    status nfe_vigia.os_status DEFAULT 'CRIADA'::nfe_vigia.os_status NOT NULL,
    provider_id uuid,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE nfe_vigia.work_orders OWNER TO postgres;

--
-- Name: work_orders_os_number_seq; Type: SEQUENCE; Schema: nfe_vigia; Owner: postgres
--

CREATE SEQUENCE nfe_vigia.work_orders_os_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe_vigia.work_orders_os_number_seq OWNER TO postgres;

--
-- Name: work_orders_os_number_seq; Type: SEQUENCE OWNED BY; Schema: nfe_vigia; Owner: postgres
--

ALTER SEQUENCE nfe_vigia.work_orders_os_number_seq OWNED BY nfe_vigia.work_orders.os_number;


--
-- Name: audit_events id; Type: DEFAULT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.audit_events ALTER COLUMN id SET DEFAULT nextval('nfe_vigia.audit_events_id_seq'::regclass);


--
-- Name: service_orders os_number; Type: DEFAULT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_orders ALTER COLUMN os_number SET DEFAULT nextval('nfe_vigia.service_orders_os_number_seq'::regclass);


--
-- Name: work_orders os_number; Type: DEFAULT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders ALTER COLUMN os_number SET DEFAULT nextval('nfe_vigia.work_orders_os_number_seq'::regclass);


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.approvals (id, condo_id, actor_user_id, action, approved_budget_id, review_reason, review_details, created_at, service_order_id, budget_id, approver_role, decision, responded_at, expires_at, is_minerva, minerva_justification, approval_type, approver_id) FROM stdin;
29d5280e-5648-4023-934e-4ec0e36adf66	a81868a8-d64f-40bb-acd2-1f892d670fcd	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	\N	\N	\N	\N	2026-03-19 00:53:44.129685+00	97804e14-4d18-452d-92a3-517131946b49	\N	CONSELHO	pendente	\N	2026-03-21 00:53:43.704+00	f	\N	ORCAMENTO	ec6306c6-4ca6-4e56-83d4-d78db0d294fe
96bed44f-ec71-45a9-90e2-eb82c665f848	a81868a8-d64f-40bb-acd2-1f892d670fcd	a6f46fd8-8882-412e-a636-b90b8bc049e6	\N	\N	\N	\N	2026-03-19 00:53:44.129685+00	97804e14-4d18-452d-92a3-517131946b49	\N	SUBSINDICO	pendente	\N	2026-03-21 00:53:43.704+00	f	\N	ORCAMENTO	a6f46fd8-8882-412e-a636-b90b8bc049e6
ae61b24f-9a6c-49ed-917a-35367146e11c	a81868a8-d64f-40bb-acd2-1f892d670fcd	e098c1b6-7c5c-48c4-9aab-21f3689776b9	\N	\N	\N	\N	2026-03-19 00:53:44.129685+00	97804e14-4d18-452d-92a3-517131946b49	\N	CONSELHO	pendente	\N	2026-03-21 00:53:43.704+00	f	\N	ORCAMENTO	e098c1b6-7c5c-48c4-9aab-21f3689776b9
c0d7c999-be16-4009-8fe1-456b54e3b619	a81868a8-d64f-40bb-acd2-1f892d670fcd	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	\N	\N	\N	\N	2026-03-19 00:53:44.129685+00	97804e14-4d18-452d-92a3-517131946b49	\N	SUBSINDICO	pendente	\N	2026-03-21 00:53:43.704+00	f	\N	ORCAMENTO	0fb0b630-a739-48bf-9c66-c8fd7cb34d72
242fc615-db9f-4b0b-8d75-be6508f4e623	a81868a8-d64f-40bb-acd2-1f892d670fcd	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	\N	\N	\N	\N	2026-03-20 21:01:43.215336+00	f5ca27f5-26b2-4307-bd44-503aa207c809	\N	CONSELHO	pendente	\N	2026-03-22 21:01:42.98+00	f	\N	ORCAMENTO	ec6306c6-4ca6-4e56-83d4-d78db0d294fe
eace9e83-cfad-4e6f-9649-9391b3fa64d3	a81868a8-d64f-40bb-acd2-1f892d670fcd	a6f46fd8-8882-412e-a636-b90b8bc049e6	\N	\N	\N	\N	2026-03-20 21:01:43.215336+00	f5ca27f5-26b2-4307-bd44-503aa207c809	\N	SUBSINDICO	pendente	\N	2026-03-22 21:01:42.98+00	f	\N	ORCAMENTO	a6f46fd8-8882-412e-a636-b90b8bc049e6
a77e1eca-b4a8-4fe7-b318-a7669cf3b6b4	a81868a8-d64f-40bb-acd2-1f892d670fcd	e098c1b6-7c5c-48c4-9aab-21f3689776b9	\N	\N	\N	\N	2026-03-20 21:01:43.215336+00	f5ca27f5-26b2-4307-bd44-503aa207c809	\N	CONSELHO	pendente	\N	2026-03-22 21:01:42.98+00	f	\N	ORCAMENTO	e098c1b6-7c5c-48c4-9aab-21f3689776b9
0a8547bc-aae7-4f48-93bc-6e6b30cbfeb8	a81868a8-d64f-40bb-acd2-1f892d670fcd	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	\N	\N	\N	\N	2026-03-20 21:01:43.215336+00	f5ca27f5-26b2-4307-bd44-503aa207c809	\N	SUBSINDICO	pendente	\N	2026-03-22 21:01:42.98+00	f	\N	ORCAMENTO	0fb0b630-a739-48bf-9c66-c8fd7cb34d72
\.


--
-- Data for Name: audit_events; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.audit_events (id, condo_id, actor_user_id, entity_type, entity_id, event_type, event_at, details) FROM stdin;
\.


--
-- Data for Name: budgets; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.budgets (id, condo_id, provider_id, amount_cents, file_id, created_by_user_id, created_at, deleted_at, service_order_id, status, description, valid_until, alcada_nivel, total_value, expires_at) FROM stdin;
d2adebc4-3497-4e3c-b3e7-caa099079838	a81868a8-d64f-40bb-acd2-1f892d670fcd	b544bc24-13b8-4a26-9dc2-dd0f1451f5fe	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-11 06:17:38.445306+00	\N	f5ca27f5-26b2-4307-bd44-503aa207c809	pendente	sefwf	2026-03-26	1	13454.00	\N
4aed038b-1e8e-4c1e-8fa0-725e7deaf991	a81868a8-d64f-40bb-acd2-1f892d670fcd	225a98a6-2808-4c21-b66e-352be25dbfa9	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-11 06:17:55.796555+00	\N	f5ca27f5-26b2-4307-bd44-503aa207c809	pendente	wdffwd	2026-04-10	1	21132.00	\N
42119a2f-aac8-48b6-8cd2-83cd32059c83	a81868a8-d64f-40bb-acd2-1f892d670fcd	d0e0600a-0177-4bee-ac9c-5970855f7f00	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-11 06:28:32.309093+00	\N	f5ca27f5-26b2-4307-bd44-503aa207c809	pendente	efwsfwf	2026-03-25	1	5200.00	\N
a7807289-c601-4341-a3c5-2a737f9b5edb	a81868a8-d64f-40bb-acd2-1f892d670fcd	225a98a6-2808-4c21-b66e-352be25dbfa9	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-11 11:00:13.095655+00	\N	f5ca27f5-26b2-4307-bd44-503aa207c809	pendente	cdee	2026-03-26	1	1234.00	\N
54353c5a-8773-4781-a98c-e5adff5b8d52	a81868a8-d64f-40bb-acd2-1f892d670fcd	b544bc24-13b8-4a26-9dc2-dd0f1451f5fe	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-18 11:15:56.996754+00	\N	97804e14-4d18-452d-92a3-517131946b49	pendente	teste testes	2026-03-31	1	14000.00	\N
bf87c7cc-27d7-44f5-9d46-9843995fbd4d	a81868a8-d64f-40bb-acd2-1f892d670fcd	2929dd14-19bd-493d-a3ce-f6a9d0078100	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-18 11:16:35.329142+00	\N	97804e14-4d18-452d-92a3-517131946b49	pendente	testes testes	2026-04-02	1	1401.00	\N
dd73614a-7255-43aa-9ef6-b7f8f9369390	a81868a8-d64f-40bb-acd2-1f892d670fcd	d0e0600a-0177-4bee-ac9c-5970855f7f00	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-18 11:17:11.134967+00	\N	97804e14-4d18-452d-92a3-517131946b49	pendente	teste testes	2026-04-02	1	1250.00	\N
b3008dd4-31b3-4e2a-a76a-b55f8226c59e	a81868a8-d64f-40bb-acd2-1f892d670fcd	2929dd14-19bd-493d-a3ce-f6a9d0078100	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-24 10:13:04.344782+00	\N	9d50886f-3cac-41c7-b8f1-500bddbc2e91	pendente	fadsgsgsg	2026-05-28	1	1200.00	\N
1c2c7bb9-f9cc-4faa-8873-d99fe04e784d	a81868a8-d64f-40bb-acd2-1f892d670fcd	b544bc24-13b8-4a26-9dc2-dd0f1451f5fe	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-24 10:13:23.411838+00	\N	9d50886f-3cac-41c7-b8f1-500bddbc2e91	pendente	cddvdasvdv	2026-05-26	1	1250.00	\N
532ee9a9-4f1e-4102-bf5c-d22046048a0a	a81868a8-d64f-40bb-acd2-1f892d670fcd	225a98a6-2808-4c21-b66e-352be25dbfa9	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-24 10:13:46.236084+00	\N	9d50886f-3cac-41c7-b8f1-500bddbc2e91	pendente	scwwfw	2026-04-30	1	2500.00	\N
\.


--
-- Data for Name: chamados; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.chamados (id, titulo, descricao, unidade, bloco, status, criado_por, condominio_id, service_order_id, close_reason, prioridade, categoria, tipo_execucao, emergencial, motivo_cancelamento, created_at) FROM stdin;
5ca72bb4-0812-4a0a-893d-99db9a9bf741	teste	teste	\N	\N	pendente_triagem	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	\N	\N	f	\N	2026-03-23 11:21:08.075417+00
353aea32-3635-41ca-bd4a-5798eee22154	SCWS	FWFWF	\N	\N	pendente_triagem	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	\N	\N	f	\N	2026-03-23 11:29:22.381766+00
57094d62-03e2-48de-94cf-4b55637eac4e	SCWS	FWFWF	WFRW	\N	pendente_triagem	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	Segurança	\N	f	\N	2026-03-23 11:29:22.635717+00
cff0710f-289b-4386-b82d-a910b3f49804	23/03	teste	23	\N	pendente_triagem	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	Hidráulico	\N	f	\N	2026-03-23 19:36:42.31745+00
d1a8380f-0ec3-41a8-ac6a-231212d7a607	salto	teste salto	203	\N	pendente_triagem	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	Hidráulico	\N	f	\N	2026-03-23 19:37:38.387497+00
e702cf5d-1b73-4270-8e13-510430475334	salto 2	ccbcksj	203	\N	pendente_triagem	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	Limpeza	\N	f	\N	2026-03-24 10:05:59.031428+00
19c78548-823a-4236-a21b-c927dd87f36f	salto externo	3 orçamentos	206	\N	pendente_triagem	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	Hidráulico	\N	f	\N	2026-03-24 10:11:48.716778+00
5ce42c23-6302-4387-910b-ccb8455fe01c	chamado subsindico	chamado subsindico	230	\N	pendente_triagem	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	\N	media	Segurança	\N	f	\N	2026-03-24 10:35:14.654553+00
\.


--
-- Data for Name: condo_approval_policies; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.condo_approval_policies (id, condo_id, policy_type, use_amount_limit, min_amount, max_amount, require_sindico, require_sub_sindico, require_conselho_fiscal, decision_mode, syndic_tiebreaker, active, created_at, updated_at) FROM stdin;
5fd3fb5d-05e4-4e68-b707-bff8b22dd762	90fbdd8d-2757-4eea-ab5d-f328db326f24	NF	f	\N	\N	t	t	t	MAIORIA	t	t	2026-03-10 11:32:34.419368+00	2026-03-10 11:32:34.419368+00
\.


--
-- Data for Name: condo_financial_config; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.condo_financial_config (id, condo_id, alcada_1_limite, alcada_2_limite, alcada_3_limite, approval_deadline_hours, notify_residents_above, monthly_limit_manutencao, monthly_limit_limpeza, monthly_limit_seguranca, annual_budget, annual_budget_alert_pct, created_at, updated_at, monthly_budget) FROM stdin;
19c41ba7-6050-4abc-be21-bfc4c2754d0b	a81868a8-d64f-40bb-acd2-1f892d670fcd	500.00	2000.00	10000.00	48	10000.00	\N	\N	\N	\N	70	2026-03-10 15:38:30.57052+00	2026-03-10 15:38:30.57052+00	\N
d1647331-b2e4-4e26-b16a-f337ec3bb4ff	90fbdd8d-2757-4eea-ab5d-f328db326f24	500.00	2000.00	10000.00	48	10000.00	\N	\N	\N	\N	70	2026-03-10 15:38:30.57052+00	2026-03-10 15:38:30.57052+00	\N
\.


--
-- Data for Name: condos; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.condos (id, name, document, created_at, updated_at, deleted_at, invite_code, invite_active, subscription_status, subscription_id, subscription_expires_at, pagarme_customer_id) FROM stdin;
90fbdd8d-2757-4eea-ab5d-f328db326f24	passaros	\N	2026-03-10 11:32:34.419368+00	2026-03-10 11:32:34.419368+00	\N	\N	f	trial	\N	\N	\N
a81868a8-d64f-40bb-acd2-1f892d670fcd	passaros	\N	2026-03-06 08:01:08.340618+00	2026-03-11 19:39:25.075801+00	\N	F5e5WZcF	t	trial	\N	\N	\N
\.


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.contracts (id, condo_id, provider_id, title, description, contract_type, value, start_date, end_date, file_url, status, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: dossiers; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.dossiers (id, condo_id, work_order_id, file_id, hash_algorithm, hash_hex, generated_at, generated_by_user_id) FROM stdin;
\.


--
-- Data for Name: files; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.files (id, condo_id, kind, storage_key, file_name, content_type, size_bytes, sha256_hex, created_by_user_id, created_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: fiscal_document_approvals; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.fiscal_document_approvals (id, condo_id, fiscal_document_id, approver_user_id, approver_role, decision, justification, voted_at, created_at, expires_at, is_minerva, minerva_justification) FROM stdin;
952afd60-81f9-42fc-a004-d0e8eaca503b	a81868a8-d64f-40bb-acd2-1f892d670fcd	3f5ebaa4-41ed-478e-941c-711f7bddc6bf	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-14 03:16:19.84+00	2026-03-14 03:16:19.988931+00	\N	f	\N
36fcf11b-2005-4602-b865-0e4503090330	a81868a8-d64f-40bb-acd2-1f892d670fcd	53a53b2f-1a05-4e3b-b085-dcbfb31f29d9	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-14 03:16:33.985+00	2026-03-14 03:16:34.129024+00	\N	f	\N
0ae15136-1e48-4188-a02d-4be16ddd1bb6	a81868a8-d64f-40bb-acd2-1f892d670fcd	5f7752a0-e61d-4687-aa33-9b376c6dc6bf	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	CONSELHO	pendente	\N	\N	2026-03-17 00:10:09.70656+00	\N	f	\N
ca9d113d-e866-4d69-99c3-9f84cc28cb58	a81868a8-d64f-40bb-acd2-1f892d670fcd	5f7752a0-e61d-4687-aa33-9b376c6dc6bf	a6f46fd8-8882-412e-a636-b90b8bc049e6	SUBSINDICO	pendente	\N	\N	2026-03-17 00:10:09.70656+00	\N	f	\N
4c624ecc-11a9-47ef-9253-8e42e4480f9b	a81868a8-d64f-40bb-acd2-1f892d670fcd	5f7752a0-e61d-4687-aa33-9b376c6dc6bf	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-17 00:10:27.596+00	2026-03-17 00:10:27.786214+00	\N	f	\N
d3e77e5f-e193-4467-a35d-ba357c2dc629	a81868a8-d64f-40bb-acd2-1f892d670fcd	07086e04-3038-485d-85e4-6d419ce2fa7a	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-17 00:10:41.196+00	2026-03-17 00:10:41.320718+00	\N	f	\N
df002264-ecd3-412d-af7f-ef3ffc87330a	a81868a8-d64f-40bb-acd2-1f892d670fcd	175646f6-d8a0-426a-884a-896617650e8b	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-17 00:10:47.284+00	2026-03-17 00:10:47.417274+00	\N	f	\N
e191fa6e-720a-46a0-bfcc-0420316483c3	a81868a8-d64f-40bb-acd2-1f892d670fcd	b4979b71-1998-443a-9594-c6aa6fbf02a0	e098c1b6-7c5c-48c4-9aab-21f3689776b9	CONSELHO	pendente	\N	\N	2026-03-17 00:12:10.792515+00	\N	f	\N
b0cd097f-d684-4ced-9216-da8665dfa9a0	a81868a8-d64f-40bb-acd2-1f892d670fcd	b4979b71-1998-443a-9594-c6aa6fbf02a0	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	pendente	\N	\N	2026-03-17 00:12:10.792515+00	\N	f	\N
285154c7-9a1e-41f4-b1de-f9ad51634c11	a81868a8-d64f-40bb-acd2-1f892d670fcd	52bbeb9a-9ea6-42fa-8422-6e6a53e67358	a6f46fd8-8882-412e-a636-b90b8bc049e6	SUBSINDICO	\N	\N	\N	2026-03-17 01:08:42.433299+00	\N	f	\N
c72b14ba-3aa6-44b3-b144-f35a5ee674d3	a81868a8-d64f-40bb-acd2-1f892d670fcd	52bbeb9a-9ea6-42fa-8422-6e6a53e67358	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-17 01:18:40.52+00	2026-03-17 01:18:40.693167+00	\N	f	\N
b11d5c69-9cef-4cc4-b92e-362f1e170a99	a81868a8-d64f-40bb-acd2-1f892d670fcd	ec040559-cbd3-4a67-86fe-138fb1f8aca3	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-17 01:25:43.272+00	2026-03-17 01:25:43.444328+00	\N	f	\N
7727ab94-1d99-400a-bbdb-91a2572155f3	a81868a8-d64f-40bb-acd2-1f892d670fcd	3120f971-49c4-469f-b34f-f2952595bbe0	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	CONSELHO	\N	\N	\N	2026-03-17 08:16:34.825764+00	\N	f	\N
2e2e1502-0713-4dc3-85fa-8cb9baf52887	a81868a8-d64f-40bb-acd2-1f892d670fcd	3120f971-49c4-469f-b34f-f2952595bbe0	a6f46fd8-8882-412e-a636-b90b8bc049e6	SUBSINDICO	\N	\N	\N	2026-03-17 08:16:34.825764+00	\N	f	\N
54a65902-77d5-4a0c-afee-69515dd396ba	a81868a8-d64f-40bb-acd2-1f892d670fcd	c84a7e67-947d-40e3-8914-053ccff4ec03	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	CONSELHO	\N	\N	\N	2026-03-17 11:35:56.1621+00	\N	f	\N
28342a3f-fb0a-4891-98d8-7568189f438d	a81868a8-d64f-40bb-acd2-1f892d670fcd	c84a7e67-947d-40e3-8914-053ccff4ec03	a6f46fd8-8882-412e-a636-b90b8bc049e6	SUBSINDICO	\N	\N	\N	2026-03-17 11:35:56.1621+00	\N	f	\N
c2e311f9-f388-4588-bcaa-5c8293576790	a81868a8-d64f-40bb-acd2-1f892d670fcd	c84a7e67-947d-40e3-8914-053ccff4ec03	e098c1b6-7c5c-48c4-9aab-21f3689776b9	CONSELHO	\N	\N	\N	2026-03-17 11:35:56.1621+00	\N	f	\N
9cb8aa83-9249-41de-b5cb-3d6cba13b6f6	a81868a8-d64f-40bb-acd2-1f892d670fcd	a3e55cab-0fd2-4b0e-b3ef-04dec0b39f1a	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	CONSELHO	\N	\N	\N	2026-03-19 12:32:07.897625+00	\N	f	\N
c5ba73d7-dfd5-4e27-a28e-9bd272a51e4d	a81868a8-d64f-40bb-acd2-1f892d670fcd	a3e55cab-0fd2-4b0e-b3ef-04dec0b39f1a	a6f46fd8-8882-412e-a636-b90b8bc049e6	SUBSINDICO	\N	\N	\N	2026-03-19 12:32:07.897625+00	\N	f	\N
6e618d29-1e02-47d7-a57b-f8a1d3c8f1dd	a81868a8-d64f-40bb-acd2-1f892d670fcd	a3e55cab-0fd2-4b0e-b3ef-04dec0b39f1a	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	urgente	2026-03-19 12:33:03.997+00	2026-03-19 12:33:04.662689+00	\N	f	\N
babcc9a9-1e16-4879-a81e-77047b94361d	a81868a8-d64f-40bb-acd2-1f892d670fcd	a3e55cab-0fd2-4b0e-b3ef-04dec0b39f1a	e098c1b6-7c5c-48c4-9aab-21f3689776b9	CONSELHO	aprovado	\N	2026-03-19 13:07:27.245+00	2026-03-19 12:32:07.897625+00	\N	f	\N
a41fd5bb-a1ac-48e9-8776-b2db70cb1c22	a81868a8-d64f-40bb-acd2-1f892d670fcd	a3e55cab-0fd2-4b0e-b3ef-04dec0b39f1a	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-20 20:20:53.467+00	2026-03-19 12:32:07.897625+00	\N	f	\N
81453cae-d648-41bb-b408-3b44ae9f6acd	a81868a8-d64f-40bb-acd2-1f892d670fcd	c84a7e67-947d-40e3-8914-053ccff4ec03	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	rejeitado	\N	2026-03-20 20:24:41.19+00	2026-03-17 11:35:56.1621+00	\N	f	\N
462360d6-fa90-4591-96c5-41d1bf4d37d8	a81868a8-d64f-40bb-acd2-1f892d670fcd	3120f971-49c4-469f-b34f-f2952595bbe0	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	SINDICO	aprovado	\N	2026-03-20 20:54:24.266+00	2026-03-20 20:54:24.387076+00	\N	f	\N
8f6d8c3a-535c-4538-b176-38408b3f237e	a81868a8-d64f-40bb-acd2-1f892d670fcd	3120f971-49c4-469f-b34f-f2952595bbe0	e098c1b6-7c5c-48c4-9aab-21f3689776b9	CONSELHO	aprovado	\N	2026-03-21 05:27:46.498+00	2026-03-17 08:16:34.825764+00	\N	f	\N
9fd24be2-28fd-42b6-bc92-1564f8caf78b	a81868a8-d64f-40bb-acd2-1f892d670fcd	52bbeb9a-9ea6-42fa-8422-6e6a53e67358	e098c1b6-7c5c-48c4-9aab-21f3689776b9	CONSELHO	aprovado	\N	2026-03-21 05:28:05.866+00	2026-03-17 01:08:42.433299+00	\N	f	\N
078a2bc3-3ef6-4318-afed-cf64774568b7	a81868a8-d64f-40bb-acd2-1f892d670fcd	3120f971-49c4-469f-b34f-f2952595bbe0	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:49:28.708+00	2026-03-17 08:16:34.825764+00	\N	f	\N
858919d2-4118-413c-a64d-35d31c8a1525	a81868a8-d64f-40bb-acd2-1f892d670fcd	52bbeb9a-9ea6-42fa-8422-6e6a53e67358	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:50:07.596+00	2026-03-21 06:50:07.697154+00	\N	f	\N
ed3da44d-382d-49fb-803f-04f54ddc36cb	a81868a8-d64f-40bb-acd2-1f892d670fcd	ec040559-cbd3-4a67-86fe-138fb1f8aca3	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:50:14.267+00	2026-03-21 06:50:14.321927+00	\N	f	\N
22fdf4c9-958c-47af-ba04-d633f4c49cfb	a81868a8-d64f-40bb-acd2-1f892d670fcd	54d2fe06-f441-4ac3-8f92-013acfed9f51	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:50:17.996+00	2026-03-21 06:50:18.05006+00	\N	f	\N
8cdb138b-2a65-45cd-9f5c-cd5ca42bc0a7	a81868a8-d64f-40bb-acd2-1f892d670fcd	86d592e5-b8fa-459d-923e-c3f0f1d623a4	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:50:21.524+00	2026-03-21 06:50:21.577408+00	\N	f	\N
647df431-aef1-4164-95ef-a969ee7a5aa5	a81868a8-d64f-40bb-acd2-1f892d670fcd	dce36777-44a3-4e03-95db-d1c3bf0c3447	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:50:33.388+00	2026-03-21 06:50:33.444255+00	\N	f	\N
c17de257-81e3-4c2f-afe9-16e3cd2c4d91	a81868a8-d64f-40bb-acd2-1f892d670fcd	560b4a81-b248-4130-a5b6-1fb6f2d23a6b	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	SUBSINDICO	aprovado	\N	2026-03-21 06:50:42.028+00	2026-03-21 06:50:42.08961+00	\N	f	\N
\.


--
-- Data for Name: fiscal_document_items; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.fiscal_document_items (id, fiscal_document_id, stock_item_id, qty, unit_price, description, created_at) FROM stdin;
\.


--
-- Data for Name: fiscal_documents; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.fiscal_documents (id, condo_id, created_by, document_type, source_type, issuer_name, issuer_document, taker_name, taker_document, document_number, series, verification_code, issue_date, service_city, service_state, gross_amount, net_amount, tax_amount, status, access_key, file_url, raw_payload, created_at, updated_at, service_order_id, approval_status, approved_by_subsindico, approved_by_subsindico_at, sindico_voto_minerva, sindico_voto_at, alcada_nivel, notify_residents, amount, supplier, number) FROM stdin;
c84a7e67-947d-40e3-8914-053ccff4ec03	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2024-01-17 00:00:00+00	\N	\N	\N	\N	\N	CANCELADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/d99cda0e-ebb5-4ef1-bd62-1e513fdb0052.PDF	\N	2026-03-17 11:35:50.098056+00	2026-03-17 11:35:50.098056+00	\N	rejeitado	\N	\N	f	\N	1	f	4791.00	ADRIELLY RENATA CONCOLATO	000.000.572
3120f971-49c4-469f-b34f-f2952595bbe0	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-08-27 00:00:00+00	\N	\N	\N	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/b9a0900f-0220-41f2-b550-2a62b4d739ea.PDF	\N	2026-03-17 08:16:32.992828+00	2026-03-17 08:16:32.992828+00	\N	pendente	\N	\N	f	\N	1	f	760.70	DEPOSITO DE MAT BASICO PARA CONST ADILSON PICHO LTDA	338925
3f5ebaa4-41ed-478e-941c-711f7bddc6bf	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	NFE	UPLOAD	FIORAMAQ MOTORES E MANGUEIRAS LTDA	\N	\N	\N	1	\N	\N	2025-04-21 00:00:00+00	\N	\N	1005.00	\N	\N	PROCESSADO	\N	nf-uploads/a81868a8-d64f-40bb-acd2-1f892d670fcd/ec5c1273-9fe8-4917-9c37-d233f4bb7a4b.PDF	\N	2026-03-14 01:24:20.387839+00	2026-03-14 01:24:20.387839+00	\N	pendente	\N	\N	f	\N	1	f	\N	\N	\N
53a53b2f-1a05-4e3b-b085-dcbfb31f29d9	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	NFE	UPLOAD	FIORAMAQ MOTORES E MANGUEIRAS LTDA	\N	\N	\N	54.557.293.0001-31	\N	\N	2025-04-21 00:00:00+00	\N	\N	1005.00	\N	\N	PROCESSADO	\N	\N	\N	2026-03-11 00:23:45.26797+00	2026-03-11 00:23:45.26797+00	f5ca27f5-26b2-4307-bd44-503aa207c809	pendente	\N	\N	f	\N	1	f	1005.00	FIORAMAQ MOTORES E MANGUEIRAS LTDA	54.557.293.0001-31
175646f6-d8a0-426a-884a-896617650e8b	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-08-28 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	\N	\N	2026-03-14 03:17:44.956754+00	2026-03-14 03:17:44.956754+00	\N	pendente	\N	\N	f	\N	1	f	1772.64	COMERCIAL DE PARAFUSOS SALTENSE LTDA	197928
07086e04-3038-485d-85e4-6d419ce2fa7a	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-09-24 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	\N	\N	2026-03-16 23:59:20.347173+00	2026-03-16 23:59:20.347173+00	\N	pendente	\N	\N	f	\N	1	f	1600.02	CASTILHO FERRO E AÇO SALTO LTDA	000.004.693
5f7752a0-e61d-4687-aa33-9b376c6dc6bf	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-06-27 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	\N	\N	2026-03-17 00:10:08.594686+00	2026-03-17 00:10:08.594686+00	\N	pendente	\N	\N	f	\N	1	f	1097.00	MIL MÁQUINAS EIRELI EPP	52808
b4979b71-1998-443a-9594-c6aa6fbf02a0	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-04-07 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	\N	\N	2026-03-17 00:12:10.281523+00	2026-03-17 00:12:10.281523+00	\N	pendente	\N	\N	f	\N	1	f	4358.40	DEPOSITO DE MATERIAIS BASICOS P/ CONSTR ADELSON PIECHO LTDA	330.902
1d5940b8-ebcb-4355-80a0-d3671bec168d	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-07-21 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/b9b70235-f24d-4b64-86b5-1f46045be8d5.PDF	\N	2026-03-17 00:28:23.741441+00	2026-03-17 00:28:23.741441+00	\N	pendente	\N	\N	f	\N	1	f	250.00	MIL MÁQUINAS EIRELI	53136
362f4379-58f5-4c4f-9b50-7edc2602580f	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-08-27 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/7b1f1894-4fb4-417c-8962-6a827080bfd1.PDF	\N	2026-03-17 00:29:16.171539+00	2026-03-17 00:29:16.171539+00	\N	pendente	\N	\N	f	\N	1	f	760.70	DEPOSITO DE MAT BASICO PARA CONST ADILSON PIECHO LTDA	338925
002a59e1-24dd-44c2-94bd-5c90bb4a1feb	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-03-25 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/c6f05e88-79c4-4abf-b7fa-177633ed2029.PDF	\N	2026-03-17 00:33:41.065229+00	2026-03-17 00:33:41.065229+00	\N	pendente	\N	\N	f	\N	1	f	717.99	DEPOSITO DE MAT BASICO PARA CONST ADILSON PIECHO LTDA	324453
31eb4aea-444c-4365-9a3d-d0c8ca44f5cb	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-03-25 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/c6f05e88-79c4-4abf-b7fa-177633ed2029.PDF	\N	2026-03-17 00:35:31.801751+00	2026-03-17 00:35:31.801751+00	\N	pendente	\N	\N	f	\N	1	f	717.99	DEPOSITO DE MAT BASICO PARA CONST ADILSON PIECHO LTDA	324453
e4de2bb7-3b13-430c-924d-5ccbb5d5301a	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-04-06 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/9c5a738c-3755-4f6b-857a-98c998165425.PDF	\N	2026-03-17 00:46:42.908122+00	2026-03-17 00:46:42.908122+00	\N	pendente	\N	\N	f	\N	1	f	3747.60	Casa&Base	330.992
a3e55cab-0fd2-4b0e-b3ef-04dec0b39f1a	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	NFE	UPLOAD	DOURADO MARMORES E GRANITOS LTDA	\N	\N	\N	55	\N	\N	2025-06-11 00:00:00+00	\N	\N	1169.22	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/9e9be9dc-4358-4f05-b9c4-cb15582a5ae1.PDF	\N	2026-03-19 12:31:47.868113+00	2026-03-19 12:31:47.868113+00	f5ca27f5-26b2-4307-bd44-503aa207c809	pendente	\N	\N	f	\N	1	f	1169.22	DOURADO MARMORES E GRANITOS LTDA	55
86d592e5-b8fa-459d-923e-c3f0f1d623a4	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-06-18 00:00:00+00	\N	\N	\N	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/3da457e7-8439-4db3-ad6d-2d03bced9eab.PDF	\N	2026-03-17 01:02:26.340796+00	2026-03-17 01:02:26.340796+00	\N	aprovado	\N	\N	f	\N	1	f	40.89	DEPOSITO DE MAT BASICO PARA CONST ADILSON PECHO LTDA	414000
52bbeb9a-9ea6-42fa-8422-6e6a53e67358	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-06-18 00:00:00+00	\N	\N	\N	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/007eeb96-18bf-4cc5-b4e0-ed6ff4d9e38a.PDF	\N	2026-03-17 01:08:41.85948+00	2026-03-17 01:08:41.85948+00	\N	pendente	\N	\N	f	\N	1	f	40.89	DEPOSITO DE MAT BASICO PARA CONST ADILSON PICCHIO LTDA	414000
ec040559-cbd3-4a67-86fe-138fb1f8aca3	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-06-06 00:00:00+00	\N	\N	\N	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/92fddd8f-860c-4dc8-a6a7-d53c93986fe1.PDF	\N	2026-03-17 01:05:47.926413+00	2026-03-17 01:05:47.926413+00	\N	aprovado	\N	\N	f	\N	1	f	340.00	MADEIREIRA AMERICA LTDA - EPP	8603
dce36777-44a3-4e03-95db-d1c3bf0c3447	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-06-06 00:00:00+00	\N	\N	\N	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/7501ead1-a227-4423-a5d9-399aa051e4e9.PDF	\N	2026-03-17 01:01:30.454573+00	2026-03-17 01:01:30.454573+00	\N	aprovado	\N	\N	f	\N	1	f	340.00	MADEIREIRA AMERICA LTDA - EPP	8603
54d2fe06-f441-4ac3-8f92-013acfed9f51	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-06-06 00:00:00+00	\N	\N	\N	\N	\N	PROCESSADO	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/92fddd8f-860c-4dc8-a6a7-d53c93986fe1.PDF	\N	2026-03-17 01:05:37.130609+00	2026-03-17 01:05:37.130609+00	\N	aprovado	\N	\N	f	\N	1	f	340.00	MADEIREIRA AMERICA LTDA - EPP	8603
560b4a81-b248-4130-a5b6-1fb6f2d23a6b	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NFE	UPLOAD	\N	\N	\N	\N	\N	\N	\N	2025-04-06 00:00:00+00	\N	\N	\N	\N	\N	PENDENTE	\N	a81868a8-d64f-40bb-acd2-1f892d670fcd/9c5a738c-3755-4f6b-857a-98c998165425.PDF	\N	2026-03-17 00:47:01.873118+00	2026-03-17 00:47:01.873118+00	\N	aprovado	\N	\N	f	\N	1	f	3747.60	Casa&Base	330.992
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.invoices (id, condo_id, invoice_type, work_order_id, provider_id, invoice_number, invoice_key, issued_at, amount_cents, file_id, created_by_user_id, created_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: provider_risk_analysis; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.provider_risk_analysis (id, provider_id, condo_id, score, nivel_risco, situacao_receita, possui_protestos, possui_processos, noticias_negativas, historico_interno, recomendacao, relatorio_completo, consultado_em, consultado_por, created_at) FROM stdin;
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.providers (id, condo_id, legal_name, trade_name, document, email, phone, has_restriction, restriction_note, created_at, updated_at, deleted_at, address, neighborhood, zip_code, website, legal_nature, share_capital, company_size, opening_date, main_activity, risk_score, risk_level, tipo_servico, status, observacoes, cidade, estado) FROM stdin;
225a98a6-2808-4c21-b66e-352be25dbfa9	a81868a8-d64f-40bb-acd2-1f892d670fcd	Empresa Teste LTDA	Prestador Teste	00.000.000/0001-00	\N	(11) 99999-9999	f	\N	2026-03-10 07:33:52.431536+00	2026-03-10 07:33:52.431536+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	ativo	\N	\N	\N
b544bc24-13b8-4a26-9dc2-dd0f1451f5fe	a81868a8-d64f-40bb-acd2-1f892d670fcd	CONECT INFORMATICA LTDA	CONECT INFORMATICA LTDA	33714364000192	\N	1144090990	f	\N	2026-03-11 01:25:39.828752+00	2026-03-11 01:42:49.509329+00	\N	JOAO XXIII, 101	JARDIM PAULISTA	13231120	\N	\N	\N	\N	\N	\N	65	\N	TI	ativo	\N	CAMPO LIMPO PAULISTA	SP
a0dfd417-9fda-42f6-83b6-851825b52cc0	a81868a8-d64f-40bb-acd2-1f892d670fcd	27.215.057 RENATO DA SILVA GUILHERME	amanda Pivatto	27215057000164	pivattoamanda56@gmail.com	1123233	f	\N	2026-03-11 06:23:50.741097+00	2026-03-11 06:24:13.246129+00	\N	Rua das Nações Unidas 600	OLARIA	13329-350	\N	\N	\N	\N	\N	\N	25	\N	TI	ativo	\N	Salto	SP
d0e0600a-0177-4bee-ac9c-5970855f7f00	a81868a8-d64f-40bb-acd2-1f892d670fcd	ANDRE LUIS BARROS 36186308839	DEIXE QUE EU FACO	41527801000197	\N	\N	f	\N	2026-03-11 06:26:21.852324+00	2026-03-11 06:26:40.216211+00	\N	\N	SALTO VILLE	13323420	\N	\N	\N	\N	\N	\N	35	\N	\N	ativo	\N	SALTO	SP
2929dd14-19bd-493d-a3ce-f6a9d0078100	a81868a8-d64f-40bb-acd2-1f892d670fcd	CLIMATIZACAO SALTENSE LTDA	CLIMATIZACAO SALTENSE LTDA	47166337000137	\N	1596913659	f	\N	2026-03-11 11:03:00.593196+00	2026-03-19 17:22:26.274774+00	\N	RUI BARBOSA, 255	CENTRO	13320230	\N	\N	\N	\N	\N	\N	72	\N	\N	ativo	\N	SALTO	SP
\.


--
-- Data for Name: residents; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.residents (id, condo_id, unit_id, full_name, document, email, phone, created_at, unit_label, block, unit, residence_type, tower_block, apartment_number, street, street_number, complement, cpf_rg, birth_date) FROM stdin;
f5e5943b-97f3-47b7-b37f-fd61cdff313b	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	amanda Pivatto	28877485809	pivattoamanda56@gmail.com	11971836927	2026-03-06 00:28:26.210236+00	\N	26	203	\N	\N	\N	\N	\N	\N	\N	\N
0d8eb004-94d4-402c-94b6-9489b6a48189	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	bruno	4564485809	zelador@teste.com	111111111111111	2026-03-08 15:44:59.776835+00	\N	26	203	\N	\N	\N	\N	\N	\N	\N	\N
646ef628-2fd3-476d-9c94-c5a119268802	a81868a8-d64f-40bb-acd2-1f892d670fcd	\N	Usuário	\N	saltofibras@gmail.com	11985246575	2026-03-14 01:00:47.472537+00	\N	26	203	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: service_order_activities; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_activities (id, service_order_id, user_id, activity_type, description, metadata, created_at) FROM stdin;
efe24412-3634-49f7-b966-8971d2e85e63	dee0705d-f621-46f1-bf92-6926b69fc11b	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	TESTE_ATIVIDADE	Teste de atividade manual	\N	2026-03-07 14:17:02.727518+00
1d3d70b3-ac80-4a96-a6da-7b183bdfd701	23223916-ce50-4a5b-bff1-836cda00bdb8	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	TESTE_ATIVIDADE	Teste manual de atividade	\N	2026-03-07 14:37:23.520073+00
58fd89fe-2a1f-4708-9627-832db012a0e9	97a46ab2-c865-40e0-909f-ce0376c64de2	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	ENVIADA_APROVACAO	Enviada para aprovação	\N	2026-03-07 14:42:23.582009+00
8d55cda4-01c2-4c8d-9684-ce7d17d2aba7	3caa068b-cc75-43a9-acc4-095d9e42f241	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	OS_CRIADA	Ordem de serviço criada	\N	2026-03-07 14:47:29.114594+00
da681aac-d4fb-4cd3-9718-111489c037e5	3caa068b-cc75-43a9-acc4-095d9e42f241	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	EXECUCAO_INICIADA	Execução iniciada	\N	2026-03-07 14:47:33.078461+00
c1300f3a-8b9a-4245-bc17-75f4320e78e6	3caa068b-cc75-43a9-acc4-095d9e42f241	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	ENVIADA_APROVACAO	Enviada para aprovação	\N	2026-03-07 14:47:38.621803+00
bc281af8-c88e-4bba-966c-59ce8b7db227	1a7ef2e2-1460-4ef9-9922-60e7e641a5d8	e098c1b6-7c5c-48c4-9aab-21f3689776b9	OS_CRIADA	Ordem de serviço criada	\N	2026-03-07 17:02:24.102639+00
89b43e23-1f70-4061-b5b4-1cc22f5dd4c4	1a7ef2e2-1460-4ef9-9922-60e7e641a5d8	e098c1b6-7c5c-48c4-9aab-21f3689776b9	FOTO_ADICIONADA	Foto 1 adicionada	\N	2026-03-07 17:02:24.282879+00
311d8ae8-98fd-4f45-a19a-5c05918db646	97804e14-4d18-452d-92a3-517131946b49	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	OS_CRIADA	Ordem de serviço criada	\N	2026-03-08 09:54:32.417413+00
800ac9f5-c771-4bed-bb64-02542e192f55	97804e14-4d18-452d-92a3-517131946b49	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	FOTO_ADICIONADA	Foto 1 adicionada	\N	2026-03-08 09:54:32.609461+00
5a0dac69-e91d-4f54-8a3d-88c808dfd764	97804e14-4d18-452d-92a3-517131946b49	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	FOTO_ADICIONADA	Foto 2 adicionada	\N	2026-03-08 09:54:32.81691+00
ace14e6d-2451-44a1-9135-ff0f714c9652	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	OS_CRIADA	Ordem de serviço criada	\N	2026-03-10 10:52:24.055883+00
b08ac8f7-be23-47db-b739-f1132734107f	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	FOTO_ADICIONADA	Foto 1 adicionada	\N	2026-03-10 10:52:24.404197+00
192b059f-a8e8-4b5d-bb1c-c8d08cb9627f	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	FOTO_ADICIONADA	Foto 2 adicionada	\N	2026-03-10 10:52:24.654594+00
dd73a6a1-9d80-4c24-bbb7-d376d7d32425	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	DOCUMENTO_ANEXADO	Nota fiscal Nº 54.557.293.0001-31 anexada	\N	2026-03-11 00:23:45.70545+00
24f923c1-f98e-48fc-b955-f6e60b9078bc	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	EXECUCAO_INICIADA	Execução iniciada	\N	2026-03-16 23:55:18.687284+00
d7676a5e-3c73-4546-9923-3fd32cec28ee	97804e14-4d18-452d-92a3-517131946b49	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	ENVIADA_APROVACAO	Orçamentos enviados para aprovação — aguardando Subsíndico e Conselheiros	\N	2026-03-18 11:48:39.764626+00
a791a895-e9c8-41bf-b451-5e0004e40986	97804e14-4d18-452d-92a3-517131946b49	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	ENVIADA_APROVACAO	Orçamentos enviados para aprovação — aguardando Subsíndico e Conselheiros	\N	2026-03-19 00:53:44.7332+00
87ebf59c-0c49-49dd-9d56-35929ddf6123	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	DOCUMENTO_ANEXADO	Nota fiscal Nº 55 anexada	\N	2026-03-19 12:31:48.264254+00
30373721-d400-4860-9f0b-fa98f95f590a	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	NF_ENVIADA_APROVACAO	NF Nº 55 (R$ 1.169,22 — alçada: SUBSINDICO, CONSELHO) enviada para aprovação	\N	2026-03-19 12:32:08.170773+00
359d62bf-edbe-4207-80ba-37edff2ad1b5	f5ca27f5-26b2-4307-bd44-503aa207c809	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	ENVIADA_APROVACAO	Orçamentos enviados para aprovação — aguardando Subsíndico e Conselheiros	\N	2026-03-20 21:01:43.600613+00
035e81c6-1381-474f-bdf7-5b2aea598a7f	318b28c9-6a9d-422b-a8ad-91f6caa5322d	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	OS_CRIADA	Ordem de serviço criada	\N	2026-03-23 12:10:52.977927+00
57bcaf40-e5f2-49f8-905c-d72de53dcb92	318b28c9-6a9d-422b-a8ad-91f6caa5322d	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	FOTO_ADICIONADA	Foto 1 adicionada	\N	2026-03-23 12:10:53.12308+00
\.


--
-- Data for Name: service_order_approvals; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_approvals (id, service_order_id, approved_by, approver_role, decision, notes, created_at, response_status, due_at, responded_at, justification, approval_type) FROM stdin;
\.


--
-- Data for Name: service_order_documents; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_documents (id, service_order_id, fiscal_document_id, document_kind, notes, created_at) FROM stdin;
\.


--
-- Data for Name: service_order_materials; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_materials (id, service_order_id, stock_item_id, quantity, unit, notes, created_at) FROM stdin;
\.


--
-- Data for Name: service_order_photos; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_photos (id, service_order_id, photo_type, file_url, created_at, observation) FROM stdin;
21737a65-31a8-44a7-af23-a136d6befa76	23223916-ce50-4a5b-bff1-836cda00bdb8	PROBLEMA	https://rvgrxtzqkygjxlwlmvvn.supabase.co/storage/v1/object/public/service-order-photos/service-orders/23223916-ce50-4a5b-bff1-836cda00bdb8/0a4fd491-97db-4f92-95a8-74720c807bca.png	2026-03-07 12:17:49.540937+00	\N
5735efa2-90ad-4b01-a13b-1f80dd554197	97a46ab2-c865-40e0-909f-ce0376c64de2	PROBLEMA	service-orders/97a46ab2-c865-40e0-909f-ce0376c64de2/e5f8c8fd-ff5f-452d-9993-a3e43722de74.png	2026-03-07 12:33:12.936277+00	\N
9953d18a-d085-4749-94a9-bb1e9c2b0ec7	1a7ef2e2-1460-4ef9-9922-60e7e641a5d8	PROBLEMA	service-orders/1a7ef2e2-1460-4ef9-9922-60e7e641a5d8/44706aa4-c9d3-4e43-9b5c-88e6e1f70afe.png	2026-03-07 17:02:23.836471+00	\N
1891251b-1e45-48e6-a4a7-a4f31195be65	97804e14-4d18-452d-92a3-517131946b49	PROBLEMA	service-orders/97804e14-4d18-452d-92a3-517131946b49/81d2d478-e81c-4b3d-9f71-52b5f67c738e.png	2026-03-08 09:54:31.778173+00	\N
846e5a1f-5dc1-475c-9640-050cdc7a71f2	97804e14-4d18-452d-92a3-517131946b49	PROBLEMA	service-orders/97804e14-4d18-452d-92a3-517131946b49/807a8325-b7c2-481d-ab20-2bb6e0e55403.png	2026-03-08 09:54:32.153497+00	\N
8611ad2c-759d-4376-a733-32583650d5c8	f5ca27f5-26b2-4307-bd44-503aa207c809	PROBLEMA	service-orders/f5ca27f5-26b2-4307-bd44-503aa207c809/8a2c60bf-133e-415e-ba57-7b861b8a3364.png	2026-03-10 10:52:23.184515+00	\N
b08cedb5-487a-4416-8b7c-e868f28a14ac	f5ca27f5-26b2-4307-bd44-503aa207c809	PROBLEMA	service-orders/f5ca27f5-26b2-4307-bd44-503aa207c809/6201eb95-1eb9-4b27-8379-5738110a7eba.png	2026-03-10 10:52:23.690284+00	\N
31bff74b-8b98-4eae-a453-c8362397bf55	318b28c9-6a9d-422b-a8ad-91f6caa5322d	PROBLEMA	service-orders/318b28c9-6a9d-422b-a8ad-91f6caa5322d/d7c115e5-86ca-43a1-9476-28e399167038.jpeg	2026-03-23 12:10:52.80268+00	wffdvvwegwefef
\.


--
-- Data for Name: service_order_quotes; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_quotes (id, service_order_id, provider_name, value, description, file_url, created_by, created_at) FROM stdin;
8cc06fa8-4e87-47ad-a4a4-0292ff6f6d31	9d50886f-3cac-41c7-b8f1-500bddbc2e91	CLIMATIZACAO SALTENSE LTDA	1200.00	ddffe	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-24 10:29:07.430592+00
84ab0ad7-c3a0-40d8-9045-f3bc2d8dfbdf	9d50886f-3cac-41c7-b8f1-500bddbc2e91	CONECT INFORMATICA LTDA	1250.00	dgsdgdsgs	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-24 10:29:18.921809+00
a8f57139-d3dd-4e6e-a0bf-de43009ed5f4	9d50886f-3cac-41c7-b8f1-500bddbc2e91	Prestador Teste	2560.00	fewfegf	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-24 10:29:32.444681+00
\.


--
-- Data for Name: service_order_votes; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_order_votes (id, service_order_id, user_id, role, vote, justification, created_at) FROM stdin;
\.


--
-- Data for Name: service_orders; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.service_orders (id, condo_id, created_by, title, description, location, status, executor_type, executor_name, execution_notes, created_at, updated_at, priority, is_emergency, emergency_justification, started_at, finished_at, provider_id, os_number, final_pdf_url, chamado_id) FROM stdin;
dee0705d-f621-46f1-bf92-6926b69fc11b	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	vazamento	agua	frente bloco 02	CANCELADA	\N	\N	\N	2026-03-07 12:02:35.519349+00	2026-03-07 12:02:35.519349+00	MEDIA	f	\N	\N	\N	\N	1	\N	\N
3190e82c-6dd9-47ad-bcf2-9e0c3d1bacf2	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	vazamento	gas	frente bloco 02	ABERTA	\N	\N	\N	2026-03-07 12:03:36.424965+00	2026-03-07 12:03:36.424965+00	ALTA	f	\N	\N	\N	\N	2	\N	\N
23223916-ce50-4a5b-bff1-836cda00bdb8	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	vazamento	ar	frente bloco 02	ABERTA	\N	\N	\N	2026-03-07 12:17:49.033657+00	2026-03-07 12:17:49.033657+00	MEDIA	f	\N	\N	\N	\N	3	\N	\N
97a46ab2-c865-40e0-909f-ce0376c64de2	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	vazamento	er	frente bloco 02	AGUARDANDO_APROVACAO	\N	\N	\N	2026-03-07 12:33:12.595032+00	2026-03-07 12:33:12.595032+00	MEDIA	f	\N	\N	\N	\N	4	\N	\N
3caa068b-cc75-43a9-acc4-095d9e42f241	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste timeline	teste	bloco 1	AGUARDANDO_APROVACAO	\N	\N	\N	2026-03-07 14:47:28.844729+00	2026-03-07 14:47:28.844729+00	MEDIA	f	\N	\N	\N	\N	5	\N	\N
1a7ef2e2-1460-4ef9-9922-60e7e641a5d8	a81868a8-d64f-40bb-acd2-1f892d670fcd	e098c1b6-7c5c-48c4-9aab-21f3689776b9	vazamento	ar	frente bloco 02	ABERTA	\N	\N	\N	2026-03-07 17:02:23.086673+00	2026-03-07 17:02:23.086673+00	ALTA	f	\N	\N	\N	\N	6	\N	\N
97804e14-4d18-452d-92a3-517131946b49	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste timeline	test	bloco 1	AGUARDANDO_APROVACAO	\N	\N	\N	2026-03-08 09:54:31.096638+00	2026-03-08 09:54:31.096638+00	MEDIA	f	\N	\N	\N	\N	7	\N	\N
f5ca27f5-26b2-4307-bd44-503aa207c809	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	tesye	teyste	\N	AGUARDANDO_APROVACAO	INTERNO	Jose	\N	2026-03-10 10:52:22.381186+00	2026-03-10 10:52:22.381186+00	MEDIA	f	\N	2026-03-18 16:28:00+00	2026-03-31 16:28:00+00	225a98a6-2808-4c21-b66e-352be25dbfa9	8	\N	\N
318b28c9-6a9d-422b-a8ad-91f6caa5322d	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	fwfw	fdwf	fwf	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 12:10:52.078337+00	2026-03-23 12:10:52.078337+00	BAIXA	f	\N	\N	\N	\N	9	\N	353aea32-3635-41ca-bd4a-5798eee22154
32bcd6ea-2560-4a57-a57a-dc157526c0ab	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste	teste	\N	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 12:25:17.307983+00	2026-03-23 12:25:17.307983+00	MEDIA	f	\N	\N	\N	\N	10	\N	5ca72bb4-0812-4a0a-893d-99db9a9bf741
cf8ba130-ea32-4a4b-94ac-b99b2d636943	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste	teste	\N	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 12:26:52.643076+00	2026-03-23 12:26:52.643076+00	MEDIA	f	\N	\N	\N	\N	11	\N	5ca72bb4-0812-4a0a-893d-99db9a9bf741
45bb9170-b35d-4caa-a1af-457de4a79a91	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste	teste	\N	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 12:39:00.316804+00	2026-03-23 12:39:00.316804+00	MEDIA	f	\N	\N	\N	\N	12	\N	5ca72bb4-0812-4a0a-893d-99db9a9bf741
5fdab786-4835-4e97-98aa-9552b8d52125	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste	teste	\N	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 18:19:50.399587+00	2026-03-23 18:19:50.399587+00	ALTA	t	\N	\N	\N	\N	15	\N	5ca72bb4-0812-4a0a-893d-99db9a9bf741
3dfa5491-6ff7-43fe-9e93-7dd25c4e65f8	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	teste	teste	\N	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 18:40:40.107014+00	2026-03-23 18:40:40.107014+00	ALTA	t	\N	\N	\N	\N	16	\N	5ca72bb4-0812-4a0a-893d-99db9a9bf741
f6f67d7a-2241-420f-9adf-9a8db140ee30	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	salto	teste salto	203	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-23 19:38:19.937093+00	2026-03-23 19:38:19.937093+00	ALTA	t	\N	\N	\N	\N	17	\N	d1a8380f-0ec3-41a8-ac6a-231212d7a607
a89f7b26-7bf6-406e-b3fb-2eaf02c182db	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	salto 2	ccbcksj	203	ABERTA	EQUIPE_INTERNA	\N	\N	2026-03-24 10:07:02.577875+00	2026-03-24 10:07:02.577875+00	ALTA	f	\N	\N	\N	\N	18	\N	e702cf5d-1b73-4270-8e13-510430475334
9d50886f-3cac-41c7-b8f1-500bddbc2e91	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	salto externo	3 orçamentos	206	AGUARDANDO_APROVACAO	PRESTADOR_EXTERNO	\N	\N	2026-03-24 10:12:19.286808+00	2026-03-24 10:12:19.286808+00	MEDIA	f	\N	\N	\N	\N	19	\N	19c78548-823a-4236-a21b-c927dd87f36f
983052ab-a457-4f8f-8723-556e3d2044c8	a81868a8-d64f-40bb-acd2-1f892d670fcd	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	chamado subsindico	chamado subsindico	230	AGUARDANDO_ORCAMENTO	PRESTADOR_EXTERNO	\N	\N	2026-03-24 10:35:52.965274+00	2026-03-24 10:35:52.965274+00	ALTA	f	\N	\N	\N	\N	20	\N	5ce42c23-6302-4387-910b-ccb8455fe01c
\.


--
-- Data for Name: sindico_transfer_logs; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.sindico_transfer_logs (id, condo_id, old_user_id, new_user_id, changed_by, old_role, new_role, old_user_deactivated, created_at) FROM stdin;
\.


--
-- Data for Name: stock_categories; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.stock_categories (id, condo_id, name, description, created_at) FROM stdin;
dc4ca38e-a420-4e45-ae16-f7cdbcbdb9a0	a81868a8-d64f-40bb-acd2-1f892d670fcd	Máquinas e Equipamentos	Cortadores de grama, lavadoras, etc.	2026-03-14 03:06:10.956638+00
43669dd4-026b-497a-b4f3-30c500456c35	a81868a8-d64f-40bb-acd2-1f892d670fcd	Ferramentas	Ferramentas manuais e elétricas	2026-03-14 03:06:10.956638+00
93f49474-84b7-4dfd-98d4-5f7d981028a6	a81868a8-d64f-40bb-acd2-1f892d670fcd	Lubrificantes e Químicos	Óleos, graxas, produtos químicos	2026-03-14 03:06:10.956638+00
8d0fb4e5-167f-4a36-8554-4c8a72b29a33	a81868a8-d64f-40bb-acd2-1f892d670fcd	Material de Limpeza	Produtos e utensílios de limpeza	2026-03-14 03:06:10.956638+00
4d66af82-8969-44df-af17-f5ed63cc96c6	a81868a8-d64f-40bb-acd2-1f892d670fcd	Material Elétrico	Fios, lâmpadas, disjuntores	2026-03-14 03:06:10.956638+00
b8228204-44ed-449a-b5c3-41eacdcd8c85	a81868a8-d64f-40bb-acd2-1f892d670fcd	Material Hidráulico	Tubos, conexões, registros	2026-03-14 03:06:10.956638+00
57330fa4-e098-4439-83b1-97f1c56540be	a81868a8-d64f-40bb-acd2-1f892d670fcd	Outros	Itens não categorizados	2026-03-14 03:06:10.956638+00
aed308df-0cbf-4b81-ab78-e54063446150	a81868a8-d64f-40bb-acd2-1f892d670fcd	MATERIAL DE CONSTRUÇÃO	\N	2026-03-17 00:01:11.1516+00
\.


--
-- Data for Name: stock_items; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.stock_items (id, condo_id, name, unit, min_qty, is_active, created_at, updated_at, deleted_at, category_id, description) FROM stdin;
2c183265-357d-4c73-b95c-fb894e89ddfc	a81868a8-d64f-40bb-acd2-1f892d670fcd	lampada	un	3.000	t	2026-03-11 01:46:42.750794+00	2026-03-14 03:06:41.898305+00	\N	4d66af82-8969-44df-af17-f5ed63cc96c6	\N
2c78469c-b5e5-4c43-82e6-14caf3120b54	a81868a8-d64f-40bb-acd2-1f892d670fcd	OLEO HUSQVARNA 1L 2 TEM POS PRO	un	1.000	t	2026-03-14 01:24:20.890853+00	2026-03-14 03:06:58.446844+00	\N	93f49474-84b7-4dfd-98d4-5f7d981028a6	\N
65fb450a-4527-40dc-b745-b98f52a5ae54	a81868a8-d64f-40bb-acd2-1f892d670fcd	OLEO LUBRIFICANTE 1 L M-10W40	un	2.000	t	2026-03-14 01:24:20.639227+00	2026-03-14 03:07:20.158094+00	\N	93f49474-84b7-4dfd-98d4-5f7d981028a6	\N
bd71c57e-3bcc-417e-b416-f2fcdcd08f7c	a81868a8-d64f-40bb-acd2-1f892d670fcd	BUCHA FISHER UNIVERSAL SX 8 10X50MM 15 SES PLUS P30W 220V	un	0.000	t	2026-03-14 03:17:45.113495+00	2026-03-14 03:17:45.113495+00	\N	\N	\N
57e19e80-b5ef-4661-ac3e-3f020c97e356	a81868a8-d64f-40bb-acd2-1f892d670fcd	BUCHA FISHER UNIVERSAL SX 8 10X50MM	un	0.000	t	2026-03-14 03:17:45.376968+00	2026-03-14 03:17:45.376968+00	\N	\N	\N
5803b29d-c902-45d6-a7f4-a9c367724909	a81868a8-d64f-40bb-acd2-1f892d670fcd	BROCA FWIN WIDEA 5DR PLUS 5X110 - TW1200	un	2.000	t	2026-03-14 03:17:45.612245+00	2026-03-16 23:57:42.513544+00	\N	43669dd4-026b-497a-b4f3-30c500456c35	\N
263b3a1c-dcb9-4349-b66d-c57a7cd97e1f	a81868a8-d64f-40bb-acd2-1f892d670fcd	TUBO REDONDO 2 1/2 X 1.50 4 BR R8115.58	un	0.000	t	2026-03-16 23:59:20.533534+00	2026-03-16 23:59:20.533534+00	\N	\N	\N
4618c30b-36cf-4de4-9bda-5abf5afb5a9f	a81868a8-d64f-40bb-acd2-1f892d670fcd	TUBO QUADRADO 20 X 20 X 2.00 10 BR R8627.30	un	0.000	t	2026-03-16 23:59:20.83881+00	2026-03-16 23:59:20.83881+00	\N	\N	\N
4efa49b2-28ee-43b3-a4e7-7384bf9b753a	a81868a8-d64f-40bb-acd2-1f892d670fcd	TUBO QUADRADO 20 X 20 X 2.00 10 BR R664.52	un	0.000	t	2026-03-16 23:59:21.043853+00	2026-03-16 23:59:21.043853+00	\N	\N	\N
4f948a88-92e8-4c55-8a95-9f5e475afae3	a81868a8-d64f-40bb-acd2-1f892d670fcd	CANTONEIRA 3/4 X 1/8 1 BR R543.83	un	0.000	t	2026-03-16 23:59:21.235815+00	2026-03-16 23:59:21.235815+00	\N	\N	\N
57345acb-f159-4ec7-8106-82d0be1da274	a81868a8-d64f-40bb-acd2-1f892d670fcd	FERRO CHATO 3/16 X 1 1/2 5 MT BR R924.31	un	0.000	t	2026-03-16 23:59:21.436273+00	2026-03-16 23:59:21.436273+00	\N	\N	\N
7c320b8d-1e28-44be-9e61-03bbe2716269	a81868a8-d64f-40bb-acd2-1f892d670fcd	BETONEIRA MENEGOTTI RENTAL 400LTS	un	0.000	t	2026-03-17 00:10:08.747752+00	2026-03-17 00:10:08.747752+00	\N	\N	\N
371e926c-465f-4557-94d1-7283c7e98f86	a81868a8-d64f-40bb-acd2-1f892d670fcd	ROMPEDOR HILTI TE 2000-AVR	un	0.000	t	2026-03-17 00:10:08.965521+00	2026-03-17 00:10:08.965521+00	\N	\N	\N
c61f2ff8-62e8-43dd-9448-27b2cadb563b	a81868a8-d64f-40bb-acd2-1f892d670fcd	RISCADORA CORTAG DE PISO CERÂMICO MASTER 155	un	0.000	t	2026-03-17 00:10:09.337498+00	2026-03-17 00:10:09.337498+00	\N	\N	\N
1c93f712-22af-40dc-acec-59a2060237c4	a81868a8-d64f-40bb-acd2-1f892d670fcd	MPA CLASE B S/F IRDAIA BLÜCOS	un	0.000	t	2026-03-17 00:12:10.409196+00	2026-03-17 00:12:10.409196+00	\N	\N	\N
f0941468-7795-4afd-8648-ce8758a3309e	a81868a8-d64f-40bb-acd2-1f892d670fcd	BETONEIRA MENEGOTTI RENTAL 400LTS - 27/05/25 A 26/06/25 - 1 PEÇA(S)	un	0.000	t	2026-03-17 00:28:24.039058+00	2026-03-17 00:28:24.039058+00	\N	\N	\N
a629c50b-0aa3-4204-a024-1911917f3de3	a81868a8-d64f-40bb-acd2-1f892d670fcd	RESINA CAL 1 COMP 36/09/2025 N8 T60,70	un	0.000	t	2026-03-17 00:29:16.379466+00	2026-03-17 00:29:16.379466+00	\N	\N	\N
165f3866-422c-448b-918b-59fb54312628	a81868a8-d64f-40bb-acd2-1f892d670fcd	ARGAMASSA MULTIPLA AS OBRAS 50 KG VOTORAN	un	0.000	t	2026-03-17 00:33:41.391206+00	2026-03-17 00:33:41.391206+00	\N	\N	\N
c16419e1-a8db-461d-9f8c-3b20562908fb	a81868a8-d64f-40bb-acd2-1f892d670fcd	MFA CLASS S S/F INDAIA BLOCOS	un	0.000	t	2026-03-17 00:46:43.244188+00	2026-03-17 00:46:43.244188+00	\N	\N	\N
328d028d-24e5-49f5-b316-d97c1222e392	a81868a8-d64f-40bb-acd2-1f892d670fcd	Tabua 30x2 3,00m pinus	un	0.000	t	2026-03-17 01:01:30.775795+00	2026-03-17 01:01:30.775795+00	\N	\N	\N
29426fb8-3c03-430e-96d9-ac59dd577c2f	a81868a8-d64f-40bb-acd2-1f892d670fcd	ACASI ADAMAL MOLDACADO KYAR	un	0.000	t	2026-03-17 01:02:26.544279+00	2026-03-17 01:02:26.544279+00	\N	\N	\N
60d85722-c86b-42b2-99c0-d4746e5be6ee	a81868a8-d64f-40bb-acd2-1f892d670fcd	Tabua 30X2 Pinus	un	0.000	t	2026-03-17 01:05:37.376825+00	2026-03-17 01:05:37.376825+00	\N	\N	\N
74ee6429-24c7-460e-b73d-20f7dd371d8e	a81868a8-d64f-40bb-acd2-1f892d670fcd	ADAMS BELGO MINEIRA KYBU R.15/2,5 77MM A GRANEL BELGO MINEIRA	un	0.000	t	2026-03-17 01:08:42.089511+00	2026-03-17 01:08:42.089511+00	\N	\N	\N
0bae72c7-9d77-4b47-a0f6-2b2b99055305	a81868a8-d64f-40bb-acd2-1f892d670fcd	LONA DUPLA J 7 X OBRAS SU AO VOTORAN VOTURAN	un	0.000	t	2026-03-17 08:16:33.44995+00	2026-03-17 08:16:33.44995+00	\N	\N	\N
949a0627-2888-4a07-932f-2a2069962636	a81868a8-d64f-40bb-acd2-1f892d670fcd	REGUA/MANGUEIRA REGUA 1 EM 1 CINGA OBRA BASALTICA KARAGOLL	un	0.000	t	2026-03-17 08:16:34.10235+00	2026-03-17 08:16:34.10235+00	\N	\N	\N
cc20a1d9-226d-4db4-a306-b83c3a9e52bc	a81868a8-d64f-40bb-acd2-1f892d670fcd	CAIXA DE COPO DESCARTAVEL	un	0.000	t	2026-03-17 11:35:51.038272+00	2026-03-17 11:35:51.038272+00	\N	\N	\N
064e5a47-58f7-4a69-87a1-2cd4982f8582	a81868a8-d64f-40bb-acd2-1f892d670fcd	ALVEJANTE PARA PISO	un	0.000	t	2026-03-17 11:35:51.5801+00	2026-03-17 11:35:51.5801+00	\N	\N	\N
b2693af3-4ae6-4c39-8f68-725592b51407	a81868a8-d64f-40bb-acd2-1f892d670fcd	FINALIZADOR	un	0.000	t	2026-03-17 11:35:51.858958+00	2026-03-17 11:35:51.858958+00	\N	\N	\N
aaa4ef14-1d06-46cf-9610-548abd297027	a81868a8-d64f-40bb-acd2-1f892d670fcd	DESINFETANTE	un	0.000	t	2026-03-17 11:35:52.119065+00	2026-03-17 11:35:52.119065+00	\N	\N	\N
004c9b8e-b7a2-4d16-9630-61bdafc21903	a81868a8-d64f-40bb-acd2-1f892d670fcd	FARDO DE PAPEL HIGIENICO CONTEM 8 FARDOS CADA FARDO COM 16 UN FOLHA DUPLA	un	0.000	t	2026-03-17 11:35:52.339265+00	2026-03-17 11:35:52.339265+00	\N	\N	\N
9df0fa51-c1bc-4037-8e96-629fac1a5023	a81868a8-d64f-40bb-acd2-1f892d670fcd	SABAO EM PO 1 KILO	un	0.000	t	2026-03-17 11:35:52.618335+00	2026-03-17 11:35:52.618335+00	\N	\N	\N
f406e5bf-5166-46e5-a40f-a6807edddb5e	a81868a8-d64f-40bb-acd2-1f892d670fcd	VASSOURA ESPREGAO	un	0.000	t	2026-03-17 11:35:52.888092+00	2026-03-17 11:35:52.888092+00	\N	\N	\N
593290d6-cc96-4746-949c-4889663ec9fd	a81868a8-d64f-40bb-acd2-1f892d670fcd	ACUCAR	un	0.000	t	2026-03-17 11:35:53.112847+00	2026-03-17 11:35:53.112847+00	\N	\N	\N
5d518912-abe8-4c3c-8ce9-dd240038b112	a81868a8-d64f-40bb-acd2-1f892d670fcd	CAFE	un	0.000	t	2026-03-17 11:35:53.331389+00	2026-03-17 11:35:53.331389+00	\N	\N	\N
38bee7c9-d35f-4068-8136-39cdba5cc0c8	a81868a8-d64f-40bb-acd2-1f892d670fcd	MULT USO MARIDAO	un	0.000	t	2026-03-17 11:35:53.558214+00	2026-03-17 11:35:53.558214+00	\N	\N	\N
f947a72d-4c60-4c53-aa30-d9876f2a78b6	a81868a8-d64f-40bb-acd2-1f892d670fcd	SANITO REFORCADO 200 LITROS	un	0.000	t	2026-03-17 11:35:53.790375+00	2026-03-17 11:35:53.790375+00	\N	\N	\N
c7988217-a0e9-4f65-bed9-59c1c4e968d4	a81868a8-d64f-40bb-acd2-1f892d670fcd	ESPONJA DE LOUCA COM 30 UN	un	0.000	t	2026-03-17 11:35:54.086415+00	2026-03-17 11:35:54.086415+00	\N	\N	\N
92d23463-62e1-4838-b06d-2d4731a90050	a81868a8-d64f-40bb-acd2-1f892d670fcd	LUVA REFORCADA TAM M	un	0.000	t	2026-03-17 11:35:54.363481+00	2026-03-17 11:35:54.363481+00	\N	\N	\N
1b76baf0-f120-44ef-ba4f-4ab480d12567	a81868a8-d64f-40bb-acd2-1f892d670fcd	LUVA REFORCADA TAM G	un	0.000	t	2026-03-17 11:35:54.619973+00	2026-03-17 11:35:54.619973+00	\N	\N	\N
20b67e45-7c53-4f3c-97e7-3a53d23c950f	a81868a8-d64f-40bb-acd2-1f892d670fcd	PA DE LIXO	un	0.000	t	2026-03-17 11:35:54.832735+00	2026-03-17 11:35:54.832735+00	\N	\N	\N
acd4bd29-97db-4768-a9ce-85fb6b368c3d	a81868a8-d64f-40bb-acd2-1f892d670fcd	RODO GRANDE G	un	0.000	t	2026-03-17 11:35:55.051808+00	2026-03-17 11:35:55.051808+00	\N	\N	\N
60d2e32f-362d-4d03-bbf0-be1fd30aa8fa	a81868a8-d64f-40bb-acd2-1f892d670fcd	ALCOOL LIQUIDO GALAO	un	0.000	t	2026-03-17 11:35:55.261873+00	2026-03-17 11:35:55.261873+00	\N	\N	\N
23ebefaa-d85f-44a1-9aa5-c7a598ad8f80	a81868a8-d64f-40bb-acd2-1f892d670fcd	PANO DE CHAO XADRES GG	un	0.000	t	2026-03-17 11:35:55.474733+00	2026-03-17 11:35:55.474733+00	\N	\N	\N
c19458df-a681-4a60-8bbf-13e17a80f618	a81868a8-d64f-40bb-acd2-1f892d670fcd	REFIL BOBINA SACO PLASTICO PEZES ANIMAL CATA CACA CAIXA COM 20 BOBINA	un	0.000	t	2026-03-17 11:35:55.706142+00	2026-03-17 11:35:55.706142+00	\N	\N	\N
b5992d33-531a-486f-a999-b479e80bdd1d	a81868a8-d64f-40bb-acd2-1f892d670fcd	CLORO GEL	un	0.000	t	2026-03-17 11:35:55.903613+00	2026-03-17 11:35:55.903613+00	\N	\N	\N
\.


--
-- Data for Name: stock_movements; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.stock_movements (id, condo_id, item_id, move_type, qty, unit_cost_cents, supplier_name, note, moved_by_user_id, moved_at, deleted_at, destination, service_order_id, fiscal_document_id) FROM stdin;
0dabc9a6-daf4-4ea6-9c8b-f61ee2c17376	a81868a8-d64f-40bb-acd2-1f892d670fcd	74ee6429-24c7-460e-b73d-20f7dd371d8e	ENTRADA	3.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 01:08:42.180601+00	\N	\N	\N	\N
0b1ca1f8-d04c-46f7-a7c2-4f932cedad04	a81868a8-d64f-40bb-acd2-1f892d670fcd	0bae72c7-9d77-4b47-a0f6-2b2b99055305	ENTRADA	18.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 08:16:33.741696+00	\N	\N	\N	\N
33f4f096-90a9-4057-a01b-70bd95ad967c	a81868a8-d64f-40bb-acd2-1f892d670fcd	949a0627-2888-4a07-932f-2a2069962636	ENTRADA	6.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 08:16:34.311807+00	\N	\N	\N	\N
f550eb4a-971a-4b76-b3ec-40a74d24f367	a81868a8-d64f-40bb-acd2-1f892d670fcd	cc20a1d9-226d-4db4-a306-b83c3a9e52bc	ENTRADA	1.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:51.181215+00	\N	\N	\N	\N
185e0688-8e97-40e7-a3da-4fd373a7e8c8	a81868a8-d64f-40bb-acd2-1f892d670fcd	064e5a47-58f7-4a69-87a1-2cd4982f8582	ENTRADA	10.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:51.67366+00	\N	\N	\N	\N
7b9afcee-bb23-4c86-8030-e9987abe8263	a81868a8-d64f-40bb-acd2-1f892d670fcd	b2693af3-4ae6-4c39-8f68-725592b51407	ENTRADA	5.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:51.945933+00	\N	\N	\N	\N
015ac45b-9296-4122-b4d7-a04012936d75	a81868a8-d64f-40bb-acd2-1f892d670fcd	aaa4ef14-1d06-46cf-9610-548abd297027	ENTRADA	15.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:52.184498+00	\N	\N	\N	\N
834b782a-1379-4417-84ab-43949b2332e9	a81868a8-d64f-40bb-acd2-1f892d670fcd	004c9b8e-b7a2-4d16-9630-61bdafc21903	ENTRADA	1.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:52.414021+00	\N	\N	\N	\N
5a1266a6-b23c-442e-b11a-eadac43d7d74	a81868a8-d64f-40bb-acd2-1f892d670fcd	9df0fa51-c1bc-4037-8e96-629fac1a5023	ENTRADA	3.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:52.707473+00	\N	\N	\N	\N
2f096bdb-de4f-4b0e-9f76-46068da97ae0	a81868a8-d64f-40bb-acd2-1f892d670fcd	f406e5bf-5166-46e5-a40f-a6807edddb5e	ENTRADA	8.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:52.950489+00	\N	\N	\N	\N
830c6a62-066b-4860-b53c-f2b78a2559c8	a81868a8-d64f-40bb-acd2-1f892d670fcd	593290d6-cc96-4746-949c-4889663ec9fd	ENTRADA	15.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:53.17314+00	\N	\N	\N	\N
70809e4f-0727-4eac-a6d7-57b0c5eaaeed	a81868a8-d64f-40bb-acd2-1f892d670fcd	5d518912-abe8-4c3c-8ce9-dd240038b112	ENTRADA	15.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:53.395826+00	\N	\N	\N	\N
c7e0a855-2b13-49b0-97e1-2f1ee6a65e6d	a81868a8-d64f-40bb-acd2-1f892d670fcd	38bee7c9-d35f-4068-8136-39cdba5cc0c8	ENTRADA	15.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:53.622229+00	\N	\N	\N	\N
9003e855-4714-4dc5-996d-a22646ae041e	a81868a8-d64f-40bb-acd2-1f892d670fcd	f947a72d-4c60-4c53-aa30-d9876f2a78b6	ENTRADA	2.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:53.854075+00	\N	\N	\N	\N
d1850014-ae74-4b9f-a84f-03e23bd7c775	a81868a8-d64f-40bb-acd2-1f892d670fcd	c7988217-a0e9-4f65-bed9-59c1c4e968d4	ENTRADA	1.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:54.150677+00	\N	\N	\N	\N
ea383f9f-948c-4c6a-8708-70970daadf71	a81868a8-d64f-40bb-acd2-1f892d670fcd	92d23463-62e1-4838-b06d-2d4731a90050	ENTRADA	10.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:54.44274+00	\N	\N	\N	\N
9b850025-c575-4b17-ba90-448bf27ce550	a81868a8-d64f-40bb-acd2-1f892d670fcd	1b76baf0-f120-44ef-ba4f-4ab480d12567	ENTRADA	10.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:54.672814+00	\N	\N	\N	\N
47ec9540-0d2d-4198-90da-9407c86abf79	a81868a8-d64f-40bb-acd2-1f892d670fcd	20b67e45-7c53-4f3c-97e7-3a53d23c950f	ENTRADA	6.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:54.894861+00	\N	\N	\N	\N
59ccda96-374d-42e8-8e3c-1bcb015c4471	a81868a8-d64f-40bb-acd2-1f892d670fcd	acd4bd29-97db-4768-a9ce-85fb6b368c3d	ENTRADA	6.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:55.118567+00	\N	\N	\N	\N
c284ddb1-eea6-46dc-97d8-041d41bd4811	a81868a8-d64f-40bb-acd2-1f892d670fcd	60d2e32f-362d-4d03-bbf0-be1fd30aa8fa	ENTRADA	5.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:55.323105+00	\N	\N	\N	\N
e25e3663-49a3-40f4-8efd-7fa150ad6219	a81868a8-d64f-40bb-acd2-1f892d670fcd	23ebefaa-d85f-44a1-9aa5-c7a598ad8f80	ENTRADA	60.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:55.543672+00	\N	\N	\N	\N
9b806fa3-a9d3-4e1a-90aa-6af99c925fc0	a81868a8-d64f-40bb-acd2-1f892d670fcd	c19458df-a681-4a60-8bbf-13e17a80f618	ENTRADA	1.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:55.76333+00	\N	\N	\N	\N
37f017d4-b006-4d20-81a5-464cc923d524	a81868a8-d64f-40bb-acd2-1f892d670fcd	b5992d33-531a-486f-a999-b479e80bdd1d	ENTRADA	15.000	\N	\N	\N	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	2026-03-17 11:35:55.963504+00	\N	\N	\N	\N
\.


--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.subscriptions (id, condo_id, provider, external_customer_id, external_subscription_id, status, updated_at, created_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ticket_files; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.ticket_files (ticket_id, file_id) FROM stdin;
\.


--
-- Data for Name: tickets; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.tickets (id, condo_id, opened_by_user_id, unit_id, title, description, category, priority, status, rejection_reason, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: units; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.units (id, condo_id, code, description, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: user_condos; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.user_condos (id, user_id, condo_id, role, is_default, created_at, status) FROM stdin;
c1e9d110-5563-4510-a2a5-fff491103180	ec6306c6-4ca6-4e56-83d4-d78db0d294fe	a81868a8-d64f-40bb-acd2-1f892d670fcd	CONSELHO	t	2026-03-08 15:11:33.726593+00	ativo
eca2c632-9d5c-4998-a303-aca8e5109b52	a6f46fd8-8882-412e-a636-b90b8bc049e6	a81868a8-d64f-40bb-acd2-1f892d670fcd	SUBSINDICO	t	2026-03-08 15:29:43.863847+00	ativo
ef8d4796-253c-4a6b-9ba1-68352d06c4c0	b03b7c47-b668-4bf4-993f-07cc846b91bf	a81868a8-d64f-40bb-acd2-1f892d670fcd	SINDICO	t	2026-03-08 15:20:24.711881+00	ativo
bdb6c2e8-73d8-4e48-924c-11ca2cab7e63	e098c1b6-7c5c-48c4-9aab-21f3689776b9	a81868a8-d64f-40bb-acd2-1f892d670fcd	CONSELHO	t	2026-03-06 09:02:06.75812+00	ativo
d97e562e-41df-415b-8895-8cf58cb123ed	d34213fb-101f-4357-ad1e-76b6f2419597	a81868a8-d64f-40bb-acd2-1f892d670fcd	ZELADOR	t	2026-03-08 14:54:19.732165+00	ativo
5d1a0cb1-f1c4-4fd5-9bd1-d2eb3fd8184d	0fb0b630-a739-48bf-9c66-c8fd7cb34d72	a81868a8-d64f-40bb-acd2-1f892d670fcd	SUBSINDICO	f	2026-03-11 20:06:18.961467+00	ativo
66ee3421-057e-459d-a2a8-813771e732ae	47d11fa7-ab6a-4eda-a4fb-b62a7e126054	a81868a8-d64f-40bb-acd2-1f892d670fcd	SINDICO	t	2026-03-06 09:02:06.75812+00	ativo
\.


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.user_sessions (id, auth_user_id, session_token, is_active, created_at) FROM stdin;
fc4b4965-fd32-424a-b840-7707a9cf3af5	b92301f8-1f45-46c0-a638-fcc18c12206f	9b57b897-e553-4ea3-a8ca-1619b0fee8ca	f	2026-03-17 07:56:16.478104+00
b3fe8a2c-c521-48c6-8d8b-dfc238f42abf	b92301f8-1f45-46c0-a638-fcc18c12206f	ded714fb-6b7d-45cc-88b2-4cc1753b1806	t	2026-03-17 08:15:48.486629+00
b8a89def-8e02-4064-95cb-6a636de27d77	a201cf11-1195-4a5a-99fd-a16c1b8cbe0a	fbd0b99e-e563-4f04-9939-76cbb0585a15	t	2026-03-18 01:10:50.725917+00
\.


--
-- Data for Name: user_units; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.user_units (user_id, unit_id, created_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.users (id, auth_user_id, condo_id, full_name, email, profile, is_active, created_at, updated_at, deleted_at, status, cpf_rg, birth_date, residence_type) FROM stdin;
7d345c27-be35-4a1d-ad17-6092c3a73886	fd8d0c03-ed9c-40f2-b566-1d16c44ec7f7	90fbdd8d-2757-4eea-ab5d-f328db326f24	Usuário	comercialmcitu@gmail.com	CONSELHO	t	2026-03-10 11:31:18.804774+00	2026-03-11 13:47:02.371139+00	\N	ativo	\N	\N	\N
30e86b38-f780-45c2-8cdb-c5d24c2029f7	74506c1b-998c-4874-bea4-2dd2d3303b06	\N	Usuário	daniel2@teste.com	ADMIN	t	2026-03-11 20:25:24.167628+00	2026-03-11 20:25:24.167628+00	\N	ativo	\N	\N	\N
d34213fb-101f-4357-ad1e-76b6f2419597	335b3dac-e061-4360-85ba-30209f4109d7	a81868a8-d64f-40bb-acd2-1f892d670fcd	Usuário Zelador	zelador@teste.com	ZELADOR	t	2026-03-08 14:48:26.872157+00	2026-03-14 01:32:43.482504+00	\N	ativo	\N	\N	\N
0fb0b630-a739-48bf-9c66-c8fd7cb34d72	b40cfb63-027f-4538-afae-020e2e359fbd	\N	Usuário	saltofibras@gmail.com	SUBSINDICO	t	2026-03-11 19:41:00.142073+00	2026-03-14 01:32:56.818767+00	\N	ativo	\N	\N	\N
ec6306c6-4ca6-4e56-83d4-d78db0d294fe	e1aa0c61-93d1-42aa-aed0-161e3a2c7c80	a81868a8-d64f-40bb-acd2-1f892d670fcd	Usuário Conselho	conselheiro@teste.com	CONSELHO	t	2026-03-08 15:01:37.861287+00	2026-03-10 06:33:28.234927+00	\N	ativo	\N	\N	\N
a6f46fd8-8882-412e-a636-b90b8bc049e6	9d88cdfd-b1ed-4f1f-bbdd-6515a97bfc56	a81868a8-d64f-40bb-acd2-1f892d670fcd	Usuário Subsíndico	subsindico@teste.com	SUBSINDICO	t	2026-03-08 15:24:24.557679+00	2026-03-10 06:33:28.234927+00	\N	ativo	\N	\N	\N
47d11fa7-ab6a-4eda-a4fb-b62a7e126054	b92301f8-1f45-46c0-a638-fcc18c12206f	a81868a8-d64f-40bb-acd2-1f892d670fcd	Usuário	teste@teste.com	SINDICO	t	2026-03-05 19:22:20.227607+00	2026-03-10 06:33:28.234927+00	\N	ativo	\N	\N	\N
b03b7c47-b668-4bf4-993f-07cc846b91bf	a70661df-1089-428b-9774-bbf8db1043a1	a81868a8-d64f-40bb-acd2-1f892d670fcd	Usuário Síndico	sindico@teste.com	SINDICO	t	2026-03-08 15:15:20.493758+00	2026-03-10 06:34:00.1886+00	\N	ativo	\N	\N	\N
e098c1b6-7c5c-48c4-9aab-21f3689776b9	a201cf11-1195-4a5a-99fd-a16c1b8cbe0a	a81868a8-d64f-40bb-acd2-1f892d670fcd	Administrador	pivattoamanda56@gmail.com	CONSELHO	t	2026-03-04 12:57:32.73947+00	2026-03-11 12:47:47.149254+00	\N	ativo	\N	\N	\N
\.


--
-- Data for Name: work_order_evidence; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.work_order_evidence (work_order_id, file_id, phase) FROM stdin;
\.


--
-- Data for Name: work_orders; Type: TABLE DATA; Schema: nfe_vigia; Owner: postgres
--

COPY nfe_vigia.work_orders (id, condo_id, ticket_id, created_by_user_id, os_number, os_type, is_emergency, emergency_justification, status, provider_id, started_at, finished_at, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Name: audit_events_id_seq; Type: SEQUENCE SET; Schema: nfe_vigia; Owner: postgres
--

SELECT pg_catalog.setval('nfe_vigia.audit_events_id_seq', 1, false);


--
-- Name: service_orders_os_number_seq; Type: SEQUENCE SET; Schema: nfe_vigia; Owner: postgres
--

SELECT pg_catalog.setval('nfe_vigia.service_orders_os_number_seq', 20, true);


--
-- Name: work_orders_os_number_seq; Type: SEQUENCE SET; Schema: nfe_vigia; Owner: postgres
--

SELECT pg_catalog.setval('nfe_vigia.work_orders_os_number_seq', 1, false);


--
-- Name: approvals approvals_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: budgets budgets_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.budgets
    ADD CONSTRAINT budgets_pkey PRIMARY KEY (id);


--
-- Name: chamados chamados_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.chamados
    ADD CONSTRAINT chamados_pkey PRIMARY KEY (id);


--
-- Name: condo_approval_policies condo_approval_policies_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condo_approval_policies
    ADD CONSTRAINT condo_approval_policies_pkey PRIMARY KEY (id);


--
-- Name: condo_financial_config condo_financial_config_condo_id_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condo_financial_config
    ADD CONSTRAINT condo_financial_config_condo_id_key UNIQUE (condo_id);


--
-- Name: condo_financial_config condo_financial_config_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condo_financial_config
    ADD CONSTRAINT condo_financial_config_pkey PRIMARY KEY (id);


--
-- Name: condos condos_invite_code_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condos
    ADD CONSTRAINT condos_invite_code_key UNIQUE (invite_code);


--
-- Name: condos condos_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condos
    ADD CONSTRAINT condos_pkey PRIMARY KEY (id);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: dossiers dossiers_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.dossiers
    ADD CONSTRAINT dossiers_pkey PRIMARY KEY (id);


--
-- Name: dossiers dossiers_work_order_id_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.dossiers
    ADD CONSTRAINT dossiers_work_order_id_key UNIQUE (work_order_id);


--
-- Name: files files_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: fiscal_document_approvals fiscal_document_approvals_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_approvals
    ADD CONSTRAINT fiscal_document_approvals_pkey PRIMARY KEY (id);


--
-- Name: fiscal_document_items fiscal_document_items_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_items
    ADD CONSTRAINT fiscal_document_items_pkey PRIMARY KEY (id);


--
-- Name: fiscal_documents fiscal_documents_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_documents
    ADD CONSTRAINT fiscal_documents_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: provider_risk_analysis provider_risk_analysis_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.provider_risk_analysis
    ADD CONSTRAINT provider_risk_analysis_pkey PRIMARY KEY (id);


--
-- Name: providers providers_condo_id_legal_name_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.providers
    ADD CONSTRAINT providers_condo_id_legal_name_key UNIQUE (condo_id, legal_name);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);


--
-- Name: residents residents_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.residents
    ADD CONSTRAINT residents_pkey PRIMARY KEY (id);


--
-- Name: service_order_activities service_order_activities_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_activities
    ADD CONSTRAINT service_order_activities_pkey PRIMARY KEY (id);


--
-- Name: service_order_approvals service_order_approvals_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_approvals
    ADD CONSTRAINT service_order_approvals_pkey PRIMARY KEY (id);


--
-- Name: service_order_documents service_order_documents_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_documents
    ADD CONSTRAINT service_order_documents_pkey PRIMARY KEY (id);


--
-- Name: service_order_materials service_order_materials_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_materials
    ADD CONSTRAINT service_order_materials_pkey PRIMARY KEY (id);


--
-- Name: service_order_photos service_order_photos_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_photos
    ADD CONSTRAINT service_order_photos_pkey PRIMARY KEY (id);


--
-- Name: service_order_quotes service_order_quotes_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_quotes
    ADD CONSTRAINT service_order_quotes_pkey PRIMARY KEY (id);


--
-- Name: service_order_votes service_order_votes_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_votes
    ADD CONSTRAINT service_order_votes_pkey PRIMARY KEY (id);


--
-- Name: service_order_votes service_order_votes_service_order_id_user_id_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_votes
    ADD CONSTRAINT service_order_votes_service_order_id_user_id_key UNIQUE (service_order_id, user_id);


--
-- Name: service_orders service_orders_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_orders
    ADD CONSTRAINT service_orders_pkey PRIMARY KEY (id);


--
-- Name: sindico_transfer_logs sindico_transfer_logs_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.sindico_transfer_logs
    ADD CONSTRAINT sindico_transfer_logs_pkey PRIMARY KEY (id);


--
-- Name: stock_categories stock_categories_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_categories
    ADD CONSTRAINT stock_categories_pkey PRIMARY KEY (id);


--
-- Name: stock_items stock_items_condo_id_name_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_items
    ADD CONSTRAINT stock_items_condo_id_name_key UNIQUE (condo_id, name);


--
-- Name: stock_items stock_items_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_items
    ADD CONSTRAINT stock_items_pkey PRIMARY KEY (id);


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: ticket_files ticket_files_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.ticket_files
    ADD CONSTRAINT ticket_files_pkey PRIMARY KEY (ticket_id, file_id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: units units_condo_id_code_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.units
    ADD CONSTRAINT units_condo_id_code_key UNIQUE (condo_id, code);


--
-- Name: units units_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: user_condos user_condos_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_condos
    ADD CONSTRAINT user_condos_pkey PRIMARY KEY (id);


--
-- Name: user_condos user_condos_user_id_condo_id_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_condos
    ADD CONSTRAINT user_condos_user_id_condo_id_key UNIQUE (user_id, condo_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_units user_units_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_units
    ADD CONSTRAINT user_units_pkey PRIMARY KEY (user_id, unit_id);


--
-- Name: users users_auth_user_id_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.users
    ADD CONSTRAINT users_auth_user_id_key UNIQUE (auth_user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: work_order_evidence work_order_evidence_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_order_evidence
    ADD CONSTRAINT work_order_evidence_pkey PRIMARY KEY (work_order_id, file_id);


--
-- Name: work_orders work_orders_condo_id_os_number_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT work_orders_condo_id_os_number_key UNIQUE (condo_id, os_number);


--
-- Name: work_orders work_orders_pkey; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT work_orders_pkey PRIMARY KEY (id);


--
-- Name: work_orders work_orders_ticket_id_key; Type: CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT work_orders_ticket_id_key UNIQUE (ticket_id);


--
-- Name: condo_financial_config_condo_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX condo_financial_config_condo_id_idx ON nfe_vigia.condo_financial_config USING btree (condo_id);


--
-- Name: condos_subscription_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX condos_subscription_id_idx ON nfe_vigia.condos USING btree (subscription_id) WHERE (subscription_id IS NOT NULL);


--
-- Name: fiscal_document_approvals_condo_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX fiscal_document_approvals_condo_id_idx ON nfe_vigia.fiscal_document_approvals USING btree (condo_id);


--
-- Name: fiscal_document_approvals_fiscal_doc_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX fiscal_document_approvals_fiscal_doc_idx ON nfe_vigia.fiscal_document_approvals USING btree (fiscal_document_id);


--
-- Name: fiscal_document_items_fiscal_doc_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX fiscal_document_items_fiscal_doc_idx ON nfe_vigia.fiscal_document_items USING btree (fiscal_document_id);


--
-- Name: fiscal_documents_condo_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX fiscal_documents_condo_id_idx ON nfe_vigia.fiscal_documents USING btree (condo_id);


--
-- Name: fiscal_documents_status_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX fiscal_documents_status_idx ON nfe_vigia.fiscal_documents USING btree (status);


--
-- Name: ix_files_condo_kind; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX ix_files_condo_kind ON nfe_vigia.files USING btree (condo_id, kind) WHERE (deleted_at IS NULL);


--
-- Name: ix_stock_mov_item; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX ix_stock_mov_item ON nfe_vigia.stock_movements USING btree (item_id) WHERE (deleted_at IS NULL);


--
-- Name: ix_tickets_condo_status; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX ix_tickets_condo_status ON nfe_vigia.tickets USING btree (condo_id, status) WHERE (deleted_at IS NULL);


--
-- Name: ix_users_condo_profile; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX ix_users_condo_profile ON nfe_vigia.users USING btree (condo_id, profile) WHERE (deleted_at IS NULL);


--
-- Name: ix_work_orders_condo_status; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX ix_work_orders_condo_status ON nfe_vigia.work_orders USING btree (condo_id, status) WHERE (deleted_at IS NULL);


--
-- Name: service_order_materials_service_order_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX service_order_materials_service_order_idx ON nfe_vigia.service_order_materials USING btree (service_order_id);


--
-- Name: stock_items_category_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX stock_items_category_id_idx ON nfe_vigia.stock_items USING btree (category_id);


--
-- Name: stock_items_condo_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX stock_items_condo_id_idx ON nfe_vigia.stock_items USING btree (condo_id);


--
-- Name: stock_movements_condo_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX stock_movements_condo_id_idx ON nfe_vigia.stock_movements USING btree (condo_id);


--
-- Name: stock_movements_fiscal_doc_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX stock_movements_fiscal_doc_idx ON nfe_vigia.stock_movements USING btree (fiscal_document_id);


--
-- Name: stock_movements_item_id_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX stock_movements_item_id_idx ON nfe_vigia.stock_movements USING btree (item_id);


--
-- Name: stock_movements_service_order_idx; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE INDEX stock_movements_service_order_idx ON nfe_vigia.stock_movements USING btree (service_order_id);


--
-- Name: uq_fiscal_approval_doc_role; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE UNIQUE INDEX uq_fiscal_approval_doc_role ON nfe_vigia.fiscal_document_approvals USING btree (fiscal_document_id, approver_role) WHERE (decision = 'pendente'::text);


--
-- Name: uq_stock_movements_fiscal_doc_condo; Type: INDEX; Schema: nfe_vigia; Owner: postgres
--

CREATE UNIQUE INDEX uq_stock_movements_fiscal_doc_condo ON nfe_vigia.stock_movements USING btree (fiscal_document_id, condo_id) WHERE ((fiscal_document_id IS NOT NULL) AND (deleted_at IS NULL));


--
-- Name: approvals trg_approvals_apply_state; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_approvals_apply_state AFTER INSERT ON nfe_vigia.approvals FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_on_approval_apply_state();

ALTER TABLE nfe_vigia.approvals DISABLE TRIGGER trg_approvals_apply_state;


--
-- Name: approvals trg_approvals_defaults; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_approvals_defaults BEFORE INSERT ON nfe_vigia.approvals FOR EACH ROW EXECUTE FUNCTION nfe_vigia.set_approvals_defaults();


--
-- Name: condos trg_condos_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_condos_updated_at BEFORE UPDATE ON nfe_vigia.condos FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: condos trg_create_default_approval_policy_for_new_condo; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_create_default_approval_policy_for_new_condo AFTER INSERT ON nfe_vigia.condos FOR EACH ROW EXECUTE FUNCTION nfe_vigia.create_default_approval_policy_for_new_condo();


--
-- Name: providers trg_providers_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_providers_updated_at BEFORE UPDATE ON nfe_vigia.providers FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: stock_movements trg_set_moved_by_user_id; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_set_moved_by_user_id BEFORE INSERT ON nfe_vigia.stock_movements FOR EACH ROW EXECUTE FUNCTION nfe_vigia.set_moved_by_user_id();


--
-- Name: service_order_approvals trg_set_service_order_approval_responded_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_set_service_order_approval_responded_at BEFORE INSERT OR UPDATE ON nfe_vigia.service_order_approvals FOR EACH ROW EXECUTE FUNCTION nfe_vigia.set_service_order_approval_responded_at();


--
-- Name: stock_items trg_stock_items_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_stock_items_updated_at BEFORE UPDATE ON nfe_vigia.stock_items FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: user_condos trg_sync_users_condo_id_from_user_condos; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_sync_users_condo_id_from_user_condos AFTER INSERT OR UPDATE ON nfe_vigia.user_condos FOR EACH ROW EXECUTE FUNCTION nfe_vigia.sync_users_condo_id_from_user_condos();


--
-- Name: tickets trg_tickets_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_tickets_updated_at BEFORE UPDATE ON nfe_vigia.tickets FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: units trg_units_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_units_updated_at BEFORE UPDATE ON nfe_vigia.units FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: fiscal_document_approvals trg_update_fiscal_document_status; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_update_fiscal_document_status AFTER INSERT OR UPDATE ON nfe_vigia.fiscal_document_approvals FOR EACH ROW EXECUTE FUNCTION nfe_vigia.update_fiscal_document_status();


--
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON nfe_vigia.users FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: work_orders trg_work_orders_3_budgets; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_work_orders_3_budgets BEFORE UPDATE OF status ON nfe_vigia.work_orders FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_enforce_3_budgets_for_standard();


--
-- Name: work_orders trg_work_orders_updated_at; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_work_orders_updated_at BEFORE UPDATE ON nfe_vigia.work_orders FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_set_updated_at();


--
-- Name: work_orders trg_work_orders_validate_classification; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER trg_work_orders_validate_classification BEFORE INSERT OR UPDATE OF os_type, emergency_justification ON nfe_vigia.work_orders FOR EACH ROW EXECUTE FUNCTION nfe_vigia.tg_validate_work_order_classification();


--
-- Name: service_orders validate_service_order_completion_trigger; Type: TRIGGER; Schema: nfe_vigia; Owner: postgres
--

CREATE TRIGGER validate_service_order_completion_trigger BEFORE UPDATE ON nfe_vigia.service_orders FOR EACH ROW EXECUTE FUNCTION nfe_vigia.validate_service_order_completion();


--
-- Name: approvals approvals_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.approvals
    ADD CONSTRAINT approvals_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: approvals approvals_approved_budget_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.approvals
    ADD CONSTRAINT approvals_approved_budget_id_fkey FOREIGN KEY (approved_budget_id) REFERENCES nfe_vigia.budgets(id);


--
-- Name: approvals approvals_budget_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.approvals
    ADD CONSTRAINT approvals_budget_id_fkey FOREIGN KEY (budget_id) REFERENCES nfe_vigia.budgets(id);


--
-- Name: approvals approvals_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.approvals
    ADD CONSTRAINT approvals_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: approvals approvals_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.approvals
    ADD CONSTRAINT approvals_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id);


--
-- Name: audit_events audit_events_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.audit_events
    ADD CONSTRAINT audit_events_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: audit_events audit_events_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.audit_events
    ADD CONSTRAINT audit_events_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: budgets budgets_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.budgets
    ADD CONSTRAINT budgets_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: budgets budgets_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.budgets
    ADD CONSTRAINT budgets_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: budgets budgets_file_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.budgets
    ADD CONSTRAINT budgets_file_id_fkey FOREIGN KEY (file_id) REFERENCES nfe_vigia.files(id);


--
-- Name: budgets budgets_provider_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.budgets
    ADD CONSTRAINT budgets_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES nfe_vigia.providers(id);


--
-- Name: budgets budgets_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.budgets
    ADD CONSTRAINT budgets_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id);


--
-- Name: condo_approval_policies condo_approval_policies_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condo_approval_policies
    ADD CONSTRAINT condo_approval_policies_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: condo_financial_config condo_financial_config_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.condo_financial_config
    ADD CONSTRAINT condo_financial_config_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: contracts contracts_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.contracts
    ADD CONSTRAINT contracts_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_created_by_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.contracts
    ADD CONSTRAINT contracts_created_by_fkey FOREIGN KEY (created_by) REFERENCES nfe_vigia.users(id);


--
-- Name: contracts contracts_provider_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.contracts
    ADD CONSTRAINT contracts_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES nfe_vigia.providers(id);


--
-- Name: dossiers dossiers_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.dossiers
    ADD CONSTRAINT dossiers_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: dossiers dossiers_file_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.dossiers
    ADD CONSTRAINT dossiers_file_id_fkey FOREIGN KEY (file_id) REFERENCES nfe_vigia.files(id);


--
-- Name: dossiers dossiers_generated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.dossiers
    ADD CONSTRAINT dossiers_generated_by_user_id_fkey FOREIGN KEY (generated_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: dossiers dossiers_work_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.dossiers
    ADD CONSTRAINT dossiers_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES nfe_vigia.work_orders(id);


--
-- Name: files files_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.files
    ADD CONSTRAINT files_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: files files_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.files
    ADD CONSTRAINT files_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: fiscal_document_approvals fiscal_document_approvals_approver_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_approvals
    ADD CONSTRAINT fiscal_document_approvals_approver_user_id_fkey FOREIGN KEY (approver_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: fiscal_document_approvals fiscal_document_approvals_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_approvals
    ADD CONSTRAINT fiscal_document_approvals_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: fiscal_document_approvals fiscal_document_approvals_fiscal_document_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_approvals
    ADD CONSTRAINT fiscal_document_approvals_fiscal_document_id_fkey FOREIGN KEY (fiscal_document_id) REFERENCES nfe_vigia.fiscal_documents(id);


--
-- Name: fiscal_document_items fiscal_document_items_fiscal_document_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_items
    ADD CONSTRAINT fiscal_document_items_fiscal_document_id_fkey FOREIGN KEY (fiscal_document_id) REFERENCES nfe_vigia.fiscal_documents(id);


--
-- Name: fiscal_document_items fiscal_document_items_stock_item_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_document_items
    ADD CONSTRAINT fiscal_document_items_stock_item_id_fkey FOREIGN KEY (stock_item_id) REFERENCES nfe_vigia.stock_items(id);


--
-- Name: fiscal_documents fiscal_documents_approved_by_subsindico_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_documents
    ADD CONSTRAINT fiscal_documents_approved_by_subsindico_fkey FOREIGN KEY (approved_by_subsindico) REFERENCES nfe_vigia.users(id);


--
-- Name: fiscal_documents fiscal_documents_condo_fk; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_documents
    ADD CONSTRAINT fiscal_documents_condo_fk FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: fiscal_documents fiscal_documents_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_documents
    ADD CONSTRAINT fiscal_documents_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: fiscal_documents fiscal_documents_created_by_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_documents
    ADD CONSTRAINT fiscal_documents_created_by_fkey FOREIGN KEY (created_by) REFERENCES nfe_vigia.users(id) ON DELETE SET NULL;


--
-- Name: fiscal_documents fiscal_documents_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.fiscal_documents
    ADD CONSTRAINT fiscal_documents_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id);


--
-- Name: work_orders fk_work_orders_provider; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT fk_work_orders_provider FOREIGN KEY (provider_id) REFERENCES nfe_vigia.providers(id);


--
-- Name: invoices invoices_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.invoices
    ADD CONSTRAINT invoices_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: invoices invoices_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.invoices
    ADD CONSTRAINT invoices_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: invoices invoices_file_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.invoices
    ADD CONSTRAINT invoices_file_id_fkey FOREIGN KEY (file_id) REFERENCES nfe_vigia.files(id);


--
-- Name: invoices invoices_provider_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.invoices
    ADD CONSTRAINT invoices_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES nfe_vigia.providers(id);


--
-- Name: invoices invoices_work_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.invoices
    ADD CONSTRAINT invoices_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES nfe_vigia.work_orders(id);


--
-- Name: provider_risk_analysis provider_risk_analysis_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.provider_risk_analysis
    ADD CONSTRAINT provider_risk_analysis_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: provider_risk_analysis provider_risk_analysis_consultado_por_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.provider_risk_analysis
    ADD CONSTRAINT provider_risk_analysis_consultado_por_fkey FOREIGN KEY (consultado_por) REFERENCES nfe_vigia.users(id);


--
-- Name: provider_risk_analysis provider_risk_analysis_provider_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.provider_risk_analysis
    ADD CONSTRAINT provider_risk_analysis_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES nfe_vigia.providers(id);


--
-- Name: providers providers_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.providers
    ADD CONSTRAINT providers_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: residents residents_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.residents
    ADD CONSTRAINT residents_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: residents residents_unit_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.residents
    ADD CONSTRAINT residents_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES nfe_vigia.units(id) ON DELETE SET NULL;


--
-- Name: service_order_activities service_order_activities_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_activities
    ADD CONSTRAINT service_order_activities_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_activities service_order_activities_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_activities
    ADD CONSTRAINT service_order_activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: service_order_approvals service_order_approvals_approved_by_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_approvals
    ADD CONSTRAINT service_order_approvals_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES nfe_vigia.users(id);


--
-- Name: service_order_approvals service_order_approvals_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_approvals
    ADD CONSTRAINT service_order_approvals_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_documents service_order_documents_fiscal_document_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_documents
    ADD CONSTRAINT service_order_documents_fiscal_document_id_fkey FOREIGN KEY (fiscal_document_id) REFERENCES nfe_vigia.fiscal_documents(id) ON DELETE CASCADE;


--
-- Name: service_order_documents service_order_documents_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_documents
    ADD CONSTRAINT service_order_documents_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_materials service_order_materials_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_materials
    ADD CONSTRAINT service_order_materials_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_materials service_order_materials_stock_item_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_materials
    ADD CONSTRAINT service_order_materials_stock_item_id_fkey FOREIGN KEY (stock_item_id) REFERENCES nfe_vigia.stock_items(id);


--
-- Name: service_order_photos service_order_photos_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_photos
    ADD CONSTRAINT service_order_photos_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_quotes service_order_quotes_created_by_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_quotes
    ADD CONSTRAINT service_order_quotes_created_by_fkey FOREIGN KEY (created_by) REFERENCES nfe_vigia.users(id);


--
-- Name: service_order_quotes service_order_quotes_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_quotes
    ADD CONSTRAINT service_order_quotes_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_votes service_order_votes_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_votes
    ADD CONSTRAINT service_order_votes_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id) ON DELETE CASCADE;


--
-- Name: service_order_votes service_order_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_order_votes
    ADD CONSTRAINT service_order_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: service_orders service_orders_chamado_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_orders
    ADD CONSTRAINT service_orders_chamado_id_fkey FOREIGN KEY (chamado_id) REFERENCES nfe_vigia.chamados(id) ON DELETE SET NULL;


--
-- Name: service_orders service_orders_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_orders
    ADD CONSTRAINT service_orders_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: service_orders service_orders_created_by_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_orders
    ADD CONSTRAINT service_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES nfe_vigia.users(id);


--
-- Name: service_orders service_orders_provider_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.service_orders
    ADD CONSTRAINT service_orders_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES nfe_vigia.providers(id);


--
-- Name: sindico_transfer_logs sindico_transfer_logs_changed_by_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.sindico_transfer_logs
    ADD CONSTRAINT sindico_transfer_logs_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES nfe_vigia.users(id);


--
-- Name: sindico_transfer_logs sindico_transfer_logs_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.sindico_transfer_logs
    ADD CONSTRAINT sindico_transfer_logs_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: sindico_transfer_logs sindico_transfer_logs_new_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.sindico_transfer_logs
    ADD CONSTRAINT sindico_transfer_logs_new_user_id_fkey FOREIGN KEY (new_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: sindico_transfer_logs sindico_transfer_logs_old_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.sindico_transfer_logs
    ADD CONSTRAINT sindico_transfer_logs_old_user_id_fkey FOREIGN KEY (old_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: stock_categories stock_categories_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_categories
    ADD CONSTRAINT stock_categories_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: stock_items stock_items_category_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_items
    ADD CONSTRAINT stock_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES nfe_vigia.stock_categories(id);


--
-- Name: stock_items stock_items_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_items
    ADD CONSTRAINT stock_items_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: stock_movements stock_movements_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_movements
    ADD CONSTRAINT stock_movements_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: stock_movements stock_movements_fiscal_document_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_movements
    ADD CONSTRAINT stock_movements_fiscal_document_id_fkey FOREIGN KEY (fiscal_document_id) REFERENCES nfe_vigia.fiscal_documents(id);


--
-- Name: stock_movements stock_movements_item_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_movements
    ADD CONSTRAINT stock_movements_item_id_fkey FOREIGN KEY (item_id) REFERENCES nfe_vigia.stock_items(id);


--
-- Name: stock_movements stock_movements_moved_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_movements
    ADD CONSTRAINT stock_movements_moved_by_user_id_fkey FOREIGN KEY (moved_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: stock_movements stock_movements_service_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.stock_movements
    ADD CONSTRAINT stock_movements_service_order_id_fkey FOREIGN KEY (service_order_id) REFERENCES nfe_vigia.service_orders(id);


--
-- Name: subscriptions subscriptions_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.subscriptions
    ADD CONSTRAINT subscriptions_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: ticket_files ticket_files_file_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.ticket_files
    ADD CONSTRAINT ticket_files_file_id_fkey FOREIGN KEY (file_id) REFERENCES nfe_vigia.files(id) ON DELETE CASCADE;


--
-- Name: ticket_files ticket_files_ticket_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.ticket_files
    ADD CONSTRAINT ticket_files_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES nfe_vigia.tickets(id) ON DELETE CASCADE;


--
-- Name: tickets tickets_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.tickets
    ADD CONSTRAINT tickets_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: tickets tickets_opened_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.tickets
    ADD CONSTRAINT tickets_opened_by_user_id_fkey FOREIGN KEY (opened_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: tickets tickets_unit_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.tickets
    ADD CONSTRAINT tickets_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES nfe_vigia.units(id);


--
-- Name: units units_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.units
    ADD CONSTRAINT units_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: user_condos user_condos_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_condos
    ADD CONSTRAINT user_condos_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id) ON DELETE CASCADE;


--
-- Name: user_condos user_condos_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_condos
    ADD CONSTRAINT user_condos_user_id_fkey FOREIGN KEY (user_id) REFERENCES nfe_vigia.users(id) ON DELETE CASCADE;


--
-- Name: user_units user_units_unit_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_units
    ADD CONSTRAINT user_units_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES nfe_vigia.units(id) ON DELETE CASCADE;


--
-- Name: user_units user_units_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.user_units
    ADD CONSTRAINT user_units_user_id_fkey FOREIGN KEY (user_id) REFERENCES nfe_vigia.users(id) ON DELETE CASCADE;


--
-- Name: users users_auth_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.users
    ADD CONSTRAINT users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: users users_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.users
    ADD CONSTRAINT users_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: work_order_evidence work_order_evidence_file_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_order_evidence
    ADD CONSTRAINT work_order_evidence_file_id_fkey FOREIGN KEY (file_id) REFERENCES nfe_vigia.files(id) ON DELETE CASCADE;


--
-- Name: work_order_evidence work_order_evidence_work_order_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_order_evidence
    ADD CONSTRAINT work_order_evidence_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES nfe_vigia.work_orders(id) ON DELETE CASCADE;


--
-- Name: work_orders work_orders_condo_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT work_orders_condo_id_fkey FOREIGN KEY (condo_id) REFERENCES nfe_vigia.condos(id);


--
-- Name: work_orders work_orders_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT work_orders_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES nfe_vigia.users(id);


--
-- Name: work_orders work_orders_ticket_id_fkey; Type: FK CONSTRAINT; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE ONLY nfe_vigia.work_orders
    ADD CONSTRAINT work_orders_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES nfe_vigia.tickets(id);


--
-- Name: residents Residents delete only in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents delete only in active condo" ON nfe_vigia.residents FOR DELETE USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents insert only in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents insert only in active condo" ON nfe_vigia.residents FOR INSERT WITH CHECK ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents only from active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents only from active condo" ON nfe_vigia.residents FOR SELECT USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents update only in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents update only in active condo" ON nfe_vigia.residents FOR UPDATE USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents: delete own condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents: delete own condo" ON nfe_vigia.residents FOR DELETE TO authenticated USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents: insert own condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents: insert own condo" ON nfe_vigia.residents FOR INSERT TO authenticated WITH CHECK ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents: read own condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents: read own condo" ON nfe_vigia.residents FOR SELECT TO authenticated USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: residents Residents: update/delete own condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Residents: update/delete own condo" ON nfe_vigia.residents FOR UPDATE TO authenticated USING ((condo_id = nfe_vigia.get_my_condo_id())) WITH CHECK ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: user_condos Sindico can update condo member roles; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Sindico can update condo member roles" ON nfe_vigia.user_condos FOR UPDATE TO authenticated USING (((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)) AND ((user_id IN ( SELECT users.id
   FROM nfe_vigia.users
  WHERE (users.auth_user_id = auth.uid()))) OR nfe_vigia.is_sindico_in_condo(condo_id))));


--
-- Name: user_condos User can insert own condo links; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "User can insert own condo links" ON nfe_vigia.user_condos FOR INSERT WITH CHECK ((user_id IN ( SELECT users.id
   FROM nfe_vigia.users
  WHERE (users.auth_user_id = auth.uid()))));


--
-- Name: user_condos User can view own condos; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "User can view own condos" ON nfe_vigia.user_condos FOR SELECT USING ((user_id IN ( SELECT users.id
   FROM nfe_vigia.users
  WHERE (users.auth_user_id = auth.uid()))));


--
-- Name: condo_approval_policies Users can delete approval policies in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can delete approval policies in active condo" ON nfe_vigia.condo_approval_policies FOR DELETE TO authenticated USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: service_order_approvals Users can delete service order approvals in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can delete service order approvals in active condo" ON nfe_vigia.service_order_approvals FOR DELETE TO authenticated USING ((service_order_id IN ( SELECT service_orders.id
   FROM nfe_vigia.service_orders
  WHERE (service_orders.condo_id = nfe_vigia.get_my_condo_id()))));


--
-- Name: condo_approval_policies Users can insert approval policies in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can insert approval policies in active condo" ON nfe_vigia.condo_approval_policies FOR INSERT TO authenticated WITH CHECK ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: service_order_approvals Users can insert service order approvals in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can insert service order approvals in active condo" ON nfe_vigia.service_order_approvals FOR INSERT TO authenticated WITH CHECK ((service_order_id IN ( SELECT service_orders.id
   FROM nfe_vigia.service_orders
  WHERE (service_orders.condo_id = nfe_vigia.get_my_condo_id()))));


--
-- Name: condo_approval_policies Users can update approval policies in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can update approval policies in active condo" ON nfe_vigia.condo_approval_policies FOR UPDATE TO authenticated USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: service_order_approvals Users can update service order approvals in active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can update service order approvals in active condo" ON nfe_vigia.service_order_approvals FOR UPDATE TO authenticated USING ((service_order_id IN ( SELECT service_orders.id
   FROM nfe_vigia.service_orders
  WHERE (service_orders.condo_id = nfe_vigia.get_my_condo_id()))));


--
-- Name: condo_approval_policies Users can view approval policies from active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can view approval policies from active condo" ON nfe_vigia.condo_approval_policies FOR SELECT TO authenticated USING ((condo_id = nfe_vigia.get_my_condo_id()));


--
-- Name: service_order_approvals Users can view service order approvals from active condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY "Users can view service order approvals from active condo" ON nfe_vigia.service_order_approvals FOR SELECT TO authenticated USING ((service_order_id IN ( SELECT service_orders.id
   FROM nfe_vigia.service_orders
  WHERE (service_orders.condo_id = nfe_vigia.get_my_condo_id()))));


--
-- Name: approvals; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.approvals ENABLE ROW LEVEL SECURITY;

--
-- Name: approvals approvals_delete; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY approvals_delete ON nfe_vigia.approvals FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = approvals.condo_id)))));


--
-- Name: approvals approvals_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY approvals_insert ON nfe_vigia.approvals FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = approvals.condo_id)))));


--
-- Name: approvals approvals_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY approvals_select ON nfe_vigia.approvals FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = approvals.condo_id)))));


--
-- Name: approvals approvals_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY approvals_update ON nfe_vigia.approvals FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = approvals.condo_id)))));


--
-- Name: audit_events; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: budgets; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.budgets ENABLE ROW LEVEL SECURITY;

--
-- Name: chamados; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.chamados ENABLE ROW LEVEL SECURITY;

--
-- Name: chamados chamados_delete; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY chamados_delete ON nfe_vigia.chamados FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = chamados.condominio_id)))));


--
-- Name: chamados chamados_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY chamados_insert ON nfe_vigia.chamados FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM (nfe_vigia.user_condos uc
     JOIN nfe_vigia.users u ON ((u.id = uc.user_id)))
  WHERE ((u.auth_user_id = auth.uid()) AND (uc.condo_id = chamados.condominio_id)))));


--
-- Name: chamados chamados_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY chamados_select ON nfe_vigia.chamados FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (nfe_vigia.user_condos uc
     JOIN nfe_vigia.users u ON ((u.id = uc.user_id)))
  WHERE ((u.auth_user_id = auth.uid()) AND (uc.condo_id = chamados.condominio_id)))));


--
-- Name: chamados chamados_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY chamados_update ON nfe_vigia.chamados FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = chamados.condominio_id)))));


--
-- Name: condo_approval_policies; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.condo_approval_policies ENABLE ROW LEVEL SECURITY;

--
-- Name: condo_financial_config; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.condo_financial_config ENABLE ROW LEVEL SECURITY;

--
-- Name: condo_financial_config condo_financial_config_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY condo_financial_config_all ON nfe_vigia.condo_financial_config TO authenticated USING (true) WITH CHECK (true);


--
-- Name: condos; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.condos ENABLE ROW LEVEL SECURITY;

--
-- Name: condos condos_insert_authenticated; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY condos_insert_authenticated ON nfe_vigia.condos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: contracts; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.contracts ENABLE ROW LEVEL SECURITY;

--
-- Name: dossiers; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.dossiers ENABLE ROW LEVEL SECURITY;

--
-- Name: files; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.files ENABLE ROW LEVEL SECURITY;

--
-- Name: fiscal_document_approvals; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.fiscal_document_approvals ENABLE ROW LEVEL SECURITY;

--
-- Name: fiscal_document_approvals fiscal_document_approvals_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY fiscal_document_approvals_all ON nfe_vigia.fiscal_document_approvals TO authenticated USING (true) WITH CHECK (true);


--
-- Name: fiscal_document_items; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.fiscal_document_items ENABLE ROW LEVEL SECURITY;

--
-- Name: fiscal_document_items fiscal_document_items_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY fiscal_document_items_all ON nfe_vigia.fiscal_document_items TO authenticated USING (true) WITH CHECK (true);


--
-- Name: fiscal_documents; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.fiscal_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: fiscal_documents fiscal_documents_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY fiscal_documents_all ON nfe_vigia.fiscal_documents TO authenticated USING (true) WITH CHECK (true);


--
-- Name: invoices; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: approvals p_approvals_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_approvals_all ON nfe_vigia.approvals TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: approvals p_approvals_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_approvals_insert ON nfe_vigia.approvals FOR INSERT WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile, 'SUBSINDICO'::nfe_vigia.user_profile, 'CONSELHO'::nfe_vigia.user_profile]))));


--
-- Name: approvals p_approvals_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_approvals_select ON nfe_vigia.approvals FOR SELECT TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: approvals p_approvals_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_approvals_update ON nfe_vigia.approvals FOR UPDATE TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: audit_events p_audit_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_audit_select ON nfe_vigia.audit_events FOR SELECT USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: budgets p_budgets_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_budgets_all ON nfe_vigia.budgets TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: condos p_condos_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_condos_select ON nfe_vigia.condos FOR SELECT USING ((id = nfe_vigia.current_condo_id_v2()));


--
-- Name: condos p_condos_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_condos_update ON nfe_vigia.condos FOR UPDATE TO authenticated USING (((id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)) AND nfe_vigia.is_sindico_in_condo(id))) WITH CHECK (((id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)) AND nfe_vigia.is_sindico_in_condo(id)));


--
-- Name: contracts p_contracts_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_contracts_all ON nfe_vigia.contracts TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: dossiers p_dossiers_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_dossiers_select ON nfe_vigia.dossiers FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: dossiers p_dossiers_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_dossiers_write ON nfe_vigia.dossiers USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: fiscal_document_approvals p_fda_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_fda_insert ON nfe_vigia.fiscal_document_approvals FOR INSERT WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: fiscal_document_approvals p_fda_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_fda_select ON nfe_vigia.fiscal_document_approvals FOR SELECT TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: fiscal_document_approvals p_fda_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_fda_update ON nfe_vigia.fiscal_document_approvals FOR UPDATE USING ((approver_user_id = nfe_vigia.current_user_id()));


--
-- Name: files p_files_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_files_insert ON nfe_vigia.files FOR INSERT WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (created_by_user_id = nfe_vigia.current_user_id())));


--
-- Name: files p_files_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_files_select ON nfe_vigia.files FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: condo_financial_config p_financial_config_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_financial_config_select ON nfe_vigia.condo_financial_config FOR SELECT TO authenticated USING ((condo_id IN ( SELECT user_condos.condo_id
   FROM nfe_vigia.user_condos
  WHERE (user_condos.user_id = auth.uid()))));


--
-- Name: condo_financial_config p_financial_config_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_financial_config_write ON nfe_vigia.condo_financial_config TO authenticated USING ((condo_id IN ( SELECT user_condos.condo_id
   FROM nfe_vigia.user_condos
  WHERE ((user_condos.user_id = auth.uid()) AND (user_condos.role = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))))));


--
-- Name: fiscal_documents p_fiscal_documents_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_fiscal_documents_all ON nfe_vigia.fiscal_documents TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: invoices p_invoices_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_invoices_select ON nfe_vigia.invoices FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: invoices p_invoices_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_invoices_write ON nfe_vigia.invoices USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: providers p_prov_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_prov_select ON nfe_vigia.providers FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: providers p_prov_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_prov_write ON nfe_vigia.providers USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: providers p_providers_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_providers_all ON nfe_vigia.providers TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: provider_risk_analysis p_risk_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_risk_select ON nfe_vigia.provider_risk_analysis FOR SELECT TO authenticated USING ((condo_id IN ( SELECT user_condos.condo_id
   FROM nfe_vigia.user_condos
  WHERE (user_condos.user_id = auth.uid()))));


--
-- Name: provider_risk_analysis p_risk_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_risk_write ON nfe_vigia.provider_risk_analysis TO authenticated USING ((condo_id IN ( SELECT user_condos.condo_id
   FROM nfe_vigia.user_condos
  WHERE ((user_condos.user_id = auth.uid()) AND (user_condos.role = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))))));


--
-- Name: service_order_activities p_service_order_activities_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_activities_insert ON nfe_vigia.service_order_activities FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_activities.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))) AND ((user_id IS NULL) OR (user_id = nfe_vigia.current_user_id()))));


--
-- Name: service_order_activities p_service_order_activities_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_activities_select ON nfe_vigia.service_order_activities FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_activities.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: service_order_documents p_service_order_documents_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_documents_insert ON nfe_vigia.service_order_documents FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_documents.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))) AND (nfe_vigia."current_role"() = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))));


--
-- Name: service_order_documents p_service_order_documents_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_documents_select ON nfe_vigia.service_order_documents FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_documents.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: service_order_materials p_service_order_materials_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_materials_insert ON nfe_vigia.service_order_materials FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_materials.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))) AND (nfe_vigia."current_role"() = ANY (ARRAY['ZELADOR'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))));


--
-- Name: service_order_materials p_service_order_materials_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_materials_select ON nfe_vigia.service_order_materials FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_materials.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: service_order_photos p_service_order_photos_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_photos_insert ON nfe_vigia.service_order_photos FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_photos.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: service_order_photos p_service_order_photos_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_order_photos_select ON nfe_vigia.service_order_photos FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.service_orders so
  WHERE ((so.id = service_order_photos.service_order_id) AND (so.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: service_orders p_service_orders_delete; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_orders_delete ON nfe_vigia.service_orders FOR DELETE USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))));


--
-- Name: service_orders p_service_orders_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_orders_insert ON nfe_vigia.service_orders FOR INSERT WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['MORADOR'::nfe_vigia.user_profile, 'ZELADOR'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile])) AND (created_by = nfe_vigia.current_user_id())));


--
-- Name: service_orders p_service_orders_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_orders_select ON nfe_vigia.service_orders FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: service_orders p_service_orders_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_service_orders_update ON nfe_vigia.service_orders FOR UPDATE USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))));


--
-- Name: sindico_transfer_logs p_sindico_logs_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_sindico_logs_insert ON nfe_vigia.sindico_transfer_logs FOR INSERT WITH CHECK ((nfe_vigia."current_role"() = 'ADMIN'::nfe_vigia.user_profile));


--
-- Name: sindico_transfer_logs p_sindico_logs_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_sindico_logs_select ON nfe_vigia.sindico_transfer_logs FOR SELECT USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: stock_categories p_stock_categories_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_categories_all ON nfe_vigia.stock_categories TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: stock_items p_stock_items_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_items_all ON nfe_vigia.stock_items TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: stock_items p_stock_items_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_items_select ON nfe_vigia.stock_items FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: stock_items p_stock_items_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_items_write ON nfe_vigia.stock_items USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: stock_movements p_stock_mov_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_mov_insert ON nfe_vigia.stock_movements FOR INSERT WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile, 'ZELADOR'::nfe_vigia.user_profile])) AND (moved_by_user_id = nfe_vigia.current_user_id())));


--
-- Name: stock_movements p_stock_mov_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_mov_select ON nfe_vigia.stock_movements FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: stock_movements p_stock_movements_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_stock_movements_all ON nfe_vigia.stock_movements TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids))) WITH CHECK ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: subscriptions p_subs_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_subs_select ON nfe_vigia.subscriptions FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: ticket_files p_ticket_files_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_ticket_files_select ON nfe_vigia.ticket_files FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.tickets t
  WHERE ((t.id = ticket_files.ticket_id) AND (t.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: ticket_files p_ticket_files_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_ticket_files_write ON nfe_vigia.ticket_files USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.tickets t
  WHERE ((t.id = ticket_files.ticket_id) AND (t.condo_id = nfe_vigia.current_condo_id_v2()) AND ((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])) OR (t.opened_by_user_id = nfe_vigia.current_user_id())))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM nfe_vigia.tickets t
  WHERE ((t.id = ticket_files.ticket_id) AND (t.condo_id = nfe_vigia.current_condo_id_v2()) AND ((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])) OR (t.opened_by_user_id = nfe_vigia.current_user_id()))))));


--
-- Name: tickets p_tickets_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_tickets_insert ON nfe_vigia.tickets FOR INSERT WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['MORADOR'::nfe_vigia.user_profile, 'ZELADOR'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile])) AND (opened_by_user_id = nfe_vigia.current_user_id())));


--
-- Name: tickets p_tickets_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_tickets_select ON nfe_vigia.tickets FOR SELECT USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND ((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])) OR (opened_by_user_id = nfe_vigia.current_user_id()))));


--
-- Name: tickets p_tickets_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_tickets_update ON nfe_vigia.tickets FOR UPDATE USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['SINDICO'::nfe_vigia.user_profile, 'ADMIN'::nfe_vigia.user_profile]))));


--
-- Name: units p_units_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_units_select ON nfe_vigia.units FOR SELECT USING ((condo_id = nfe_vigia.current_condo_id_v2()));


--
-- Name: units p_units_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_units_write ON nfe_vigia.units USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: user_condos p_user_condos_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_user_condos_select ON nfe_vigia.user_condos FOR SELECT TO authenticated USING ((condo_id IN ( SELECT nfe_vigia.get_user_condo_ids() AS get_user_condo_ids)));


--
-- Name: user_sessions p_user_sessions_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_user_sessions_all ON nfe_vigia.user_sessions TO authenticated USING ((auth_user_id = auth.uid())) WITH CHECK ((auth_user_id = auth.uid()));


--
-- Name: user_units p_user_units_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_user_units_select ON nfe_vigia.user_units FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.units un
  WHERE ((un.id = user_units.unit_id) AND (un.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: user_units p_user_units_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_user_units_write ON nfe_vigia.user_units USING (((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])) AND (EXISTS ( SELECT 1
   FROM nfe_vigia.units un
  WHERE ((un.id = user_units.unit_id) AND (un.condo_id = nfe_vigia.current_condo_id_v2())))))) WITH CHECK (((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])) AND (EXISTS ( SELECT 1
   FROM nfe_vigia.units un
  WHERE ((un.id = user_units.unit_id) AND (un.condo_id = nfe_vigia.current_condo_id_v2()))))));


--
-- Name: users p_users_delete; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_users_delete ON nfe_vigia.users FOR DELETE USING ((nfe_vigia."current_role"() = 'ADMIN'::nfe_vigia.user_profile));


--
-- Name: users p_users_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_users_insert ON nfe_vigia.users FOR INSERT WITH CHECK ((nfe_vigia."current_role"() = 'ADMIN'::nfe_vigia.user_profile));


--
-- Name: users p_users_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_users_select ON nfe_vigia.users FOR SELECT USING (((auth.uid() IS NOT NULL) AND (condo_id = nfe_vigia.current_condo_id_v2())));


--
-- Name: users p_users_select_own; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_users_select_own ON nfe_vigia.users FOR SELECT USING ((auth_user_id = auth.uid()));


--
-- Name: users p_users_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_users_update ON nfe_vigia.users FOR UPDATE USING ((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])));


--
-- Name: users p_users_update_own; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_users_update_own ON nfe_vigia.users FOR UPDATE USING ((auth_user_id = auth.uid())) WITH CHECK ((auth_user_id = auth.uid()));


--
-- Name: work_order_evidence p_wo_evidence_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_wo_evidence_select ON nfe_vigia.work_order_evidence FOR SELECT USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.work_orders wo
  WHERE ((wo.id = work_order_evidence.work_order_id) AND (wo.condo_id = nfe_vigia.current_condo_id_v2())))));


--
-- Name: work_order_evidence p_wo_evidence_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_wo_evidence_write ON nfe_vigia.work_order_evidence USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.work_orders wo
  WHERE ((wo.id = work_order_evidence.work_order_id) AND (wo.condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM nfe_vigia.work_orders wo
  WHERE ((wo.id = work_order_evidence.work_order_id) AND (wo.condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))))));


--
-- Name: work_orders p_wo_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_wo_select ON nfe_vigia.work_orders FOR SELECT USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND ((nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile, 'SUBSINDICO'::nfe_vigia.user_profile, 'CONSELHO'::nfe_vigia.user_profile])) OR (EXISTS ( SELECT 1
   FROM nfe_vigia.tickets t
  WHERE ((t.id = work_orders.ticket_id) AND (t.opened_by_user_id = nfe_vigia.current_user_id())))))));


--
-- Name: work_orders p_wo_write; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY p_wo_write ON nfe_vigia.work_orders USING (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile])))) WITH CHECK (((condo_id = nfe_vigia.current_condo_id_v2()) AND (nfe_vigia."current_role"() = ANY (ARRAY['ADMIN'::nfe_vigia.user_profile, 'SINDICO'::nfe_vigia.user_profile]))));


--
-- Name: provider_risk_analysis; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.provider_risk_analysis ENABLE ROW LEVEL SECURITY;

--
-- Name: providers; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.providers ENABLE ROW LEVEL SECURITY;

--
-- Name: providers providers_delete; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY providers_delete ON nfe_vigia.providers FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = providers.condo_id)))));


--
-- Name: providers providers_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY providers_insert ON nfe_vigia.providers FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = providers.condo_id)))));


--
-- Name: providers providers_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY providers_select ON nfe_vigia.providers FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = providers.condo_id)))));


--
-- Name: providers providers_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY providers_update ON nfe_vigia.providers FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM nfe_vigia.user_condos uc
  WHERE ((uc.user_id = auth.uid()) AND (uc.condo_id = providers.condo_id)))));


--
-- Name: service_order_quotes quotes_condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY quotes_condo ON nfe_vigia.service_order_quotes USING ((EXISTS ( SELECT 1
   FROM ((nfe_vigia.service_orders so
     JOIN nfe_vigia.user_condos uc ON ((uc.condo_id = so.condo_id)))
     JOIN nfe_vigia.users u ON ((u.id = uc.user_id)))
  WHERE ((so.id = service_order_quotes.service_order_id) AND (u.auth_user_id = auth.uid())))));


--
-- Name: residents; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.residents ENABLE ROW LEVEL SECURITY;

--
-- Name: provider_risk_analysis risk_insert; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY risk_insert ON nfe_vigia.provider_risk_analysis FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM (nfe_vigia.providers p
     JOIN nfe_vigia.user_condos uc ON ((uc.condo_id = p.condo_id)))
  WHERE ((p.id = provider_risk_analysis.provider_id) AND (uc.user_id = auth.uid())))));


--
-- Name: provider_risk_analysis risk_select; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY risk_select ON nfe_vigia.provider_risk_analysis FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (nfe_vigia.providers p
     JOIN nfe_vigia.user_condos uc ON ((uc.condo_id = p.condo_id)))
  WHERE ((p.id = provider_risk_analysis.provider_id) AND (uc.user_id = auth.uid())))));


--
-- Name: provider_risk_analysis risk_update; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY risk_update ON nfe_vigia.provider_risk_analysis FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (nfe_vigia.providers p
     JOIN nfe_vigia.user_condos uc ON ((uc.condo_id = p.condo_id)))
  WHERE ((p.id = provider_risk_analysis.provider_id) AND (uc.user_id = auth.uid())))));


--
-- Name: service_order_activities; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_approvals; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_approvals ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_documents; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_materials; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_materials service_order_materials_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY service_order_materials_all ON nfe_vigia.service_order_materials TO authenticated USING (true) WITH CHECK (true);


--
-- Name: service_order_photos; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_photos ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_quotes; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_quotes ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_votes; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_order_votes ENABLE ROW LEVEL SECURITY;

--
-- Name: service_orders; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.service_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: sindico_transfer_logs; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.sindico_transfer_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_categories; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.stock_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_categories stock_categories_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY stock_categories_all ON nfe_vigia.stock_categories TO authenticated USING (true) WITH CHECK (true);


--
-- Name: stock_items; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.stock_items ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_items stock_items_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY stock_items_all ON nfe_vigia.stock_items TO authenticated USING (true) WITH CHECK (true);


--
-- Name: stock_movements; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.stock_movements ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_movements stock_movements_all; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY stock_movements_all ON nfe_vigia.stock_movements TO authenticated USING (true) WITH CHECK (true);


--
-- Name: subscriptions; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: ticket_files; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.ticket_files ENABLE ROW LEVEL SECURITY;

--
-- Name: tickets; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.tickets ENABLE ROW LEVEL SECURITY;

--
-- Name: units; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.units ENABLE ROW LEVEL SECURITY;

--
-- Name: user_sessions; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.user_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_units; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.user_units ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.users ENABLE ROW LEVEL SECURITY;

--
-- Name: service_order_votes votes_condo; Type: POLICY; Schema: nfe_vigia; Owner: postgres
--

CREATE POLICY votes_condo ON nfe_vigia.service_order_votes USING ((EXISTS ( SELECT 1
   FROM ((nfe_vigia.service_orders so
     JOIN nfe_vigia.user_condos uc ON ((uc.condo_id = so.condo_id)))
     JOIN nfe_vigia.users u ON ((u.id = uc.user_id)))
  WHERE ((so.id = service_order_votes.service_order_id) AND (u.auth_user_id = auth.uid())))));


--
-- Name: work_order_evidence; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.work_order_evidence ENABLE ROW LEVEL SECURITY;

--
-- Name: work_orders; Type: ROW SECURITY; Schema: nfe_vigia; Owner: postgres
--

ALTER TABLE nfe_vigia.work_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA nfe_vigia; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA nfe_vigia TO authenticated;
GRANT USAGE ON SCHEMA nfe_vigia TO anon;


--
-- Name: TABLE users; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.users TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.users TO anon;


--
-- Name: FUNCTION onboard_create_condo(p_name text, p_document text); Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON FUNCTION nfe_vigia.onboard_create_condo(p_name text, p_document text) TO anon;
GRANT ALL ON FUNCTION nfe_vigia.onboard_create_condo(p_name text, p_document text) TO authenticated;


--
-- Name: TABLE approvals; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.approvals TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.approvals TO anon;


--
-- Name: TABLE audit_events; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.audit_events TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.audit_events TO anon;


--
-- Name: TABLE budgets; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.budgets TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.budgets TO anon;


--
-- Name: TABLE chamados; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.chamados TO anon;
GRANT ALL ON TABLE nfe_vigia.chamados TO authenticated;


--
-- Name: TABLE condo_approval_policies; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.condo_approval_policies TO anon;
GRANT ALL ON TABLE nfe_vigia.condo_approval_policies TO authenticated;


--
-- Name: TABLE condo_financial_config; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.condo_financial_config TO anon;
GRANT ALL ON TABLE nfe_vigia.condo_financial_config TO authenticated;


--
-- Name: TABLE condos; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.condos TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.condos TO anon;


--
-- Name: TABLE contracts; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.contracts TO anon;
GRANT ALL ON TABLE nfe_vigia.contracts TO authenticated;


--
-- Name: TABLE dossiers; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.dossiers TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.dossiers TO anon;


--
-- Name: TABLE files; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.files TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.files TO anon;


--
-- Name: TABLE fiscal_document_approvals; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.fiscal_document_approvals TO anon;
GRANT ALL ON TABLE nfe_vigia.fiscal_document_approvals TO authenticated;


--
-- Name: TABLE fiscal_document_items; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.fiscal_document_items TO anon;
GRANT ALL ON TABLE nfe_vigia.fiscal_document_items TO authenticated;


--
-- Name: TABLE fiscal_documents; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.fiscal_documents TO anon;
GRANT ALL ON TABLE nfe_vigia.fiscal_documents TO authenticated;


--
-- Name: TABLE invoices; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.invoices TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.invoices TO anon;


--
-- Name: TABLE provider_risk_analysis; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.provider_risk_analysis TO anon;
GRANT ALL ON TABLE nfe_vigia.provider_risk_analysis TO authenticated;


--
-- Name: TABLE providers; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.providers TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.providers TO anon;


--
-- Name: TABLE residents; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.residents TO anon;
GRANT ALL ON TABLE nfe_vigia.residents TO authenticated;


--
-- Name: TABLE service_order_activities; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_activities TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_activities TO authenticated;


--
-- Name: TABLE service_order_approvals; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_approvals TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_approvals TO authenticated;


--
-- Name: TABLE service_order_documents; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_documents TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_documents TO authenticated;


--
-- Name: TABLE service_order_materials; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_materials TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_materials TO authenticated;


--
-- Name: TABLE service_order_photos; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_photos TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_photos TO authenticated;


--
-- Name: TABLE service_order_quotes; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_quotes TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_quotes TO authenticated;


--
-- Name: TABLE service_order_votes; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_order_votes TO anon;
GRANT ALL ON TABLE nfe_vigia.service_order_votes TO authenticated;


--
-- Name: TABLE service_orders; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.service_orders TO anon;
GRANT ALL ON TABLE nfe_vigia.service_orders TO authenticated;


--
-- Name: SEQUENCE service_orders_os_number_seq; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON SEQUENCE nfe_vigia.service_orders_os_number_seq TO authenticated;


--
-- Name: TABLE sindico_transfer_logs; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.sindico_transfer_logs TO anon;
GRANT ALL ON TABLE nfe_vigia.sindico_transfer_logs TO authenticated;


--
-- Name: TABLE stock_categories; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.stock_categories TO anon;
GRANT ALL ON TABLE nfe_vigia.stock_categories TO authenticated;


--
-- Name: TABLE stock_items; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.stock_items TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.stock_items TO anon;


--
-- Name: TABLE stock_movements; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.stock_movements TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.stock_movements TO anon;


--
-- Name: TABLE subscriptions; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.subscriptions TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.subscriptions TO anon;


--
-- Name: TABLE ticket_files; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.ticket_files TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.ticket_files TO anon;


--
-- Name: TABLE tickets; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.tickets TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.tickets TO anon;


--
-- Name: TABLE units; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.units TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.units TO anon;


--
-- Name: TABLE user_condos; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.user_condos TO anon;
GRANT ALL ON TABLE nfe_vigia.user_condos TO authenticated;


--
-- Name: TABLE user_sessions; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.user_sessions TO anon;
GRANT ALL ON TABLE nfe_vigia.user_sessions TO authenticated;


--
-- Name: TABLE user_units; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.user_units TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.user_units TO anon;


--
-- Name: TABLE v_stock_balance; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.v_stock_balance TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.v_stock_balance TO anon;


--
-- Name: TABLE work_order_evidence; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.work_order_evidence TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.work_order_evidence TO anon;


--
-- Name: TABLE work_orders; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT ALL ON TABLE nfe_vigia.work_orders TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe_vigia.work_orders TO anon;


--
-- Name: SEQUENCE work_orders_os_number_seq; Type: ACL; Schema: nfe_vigia; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE nfe_vigia.work_orders_os_number_seq TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: nfe_vigia; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA nfe_vigia GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA nfe_vigia GRANT ALL ON TABLES TO authenticated;


--
-- PostgreSQL database dump complete
--

\unrestrict I08DVs4PSwWvllqnGEDjyqhxfZz0HKVeYfLgG35e4hqdOgsOakI5lIFpSN1ubvA

