alter table ai_provider_settings
  add column if not exists embedding_dimensions_param boolean not null default true,
  add column if not exists llm_extra_body jsonb not null default '{}';

delete from ai_provider_settings where id = 'global';
