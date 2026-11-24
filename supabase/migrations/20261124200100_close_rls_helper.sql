-- Supabase's rls_auto_enable() turns on row-level security for every new table in public (it runs as an
-- event trigger). It lives in public, so the API lists it for anyone. Calling it directly does nothing,
-- but nobody outside the server should be able to: close it. The event trigger keeps working, because
-- PostgreSQL checks EXECUTE only when a trigger is created, not when it fires.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end
$$;
