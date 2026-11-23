-- FunBrushBoxApp - Diş Randevuları Tablosu
-- Supabase SQL Editor'de çalıştırarak tabloyu oluşturabilirsiniz.

create table if not exists public.dis_randevulari (
  id text primary key,
  cihaz_id text not null,
  firca_id text,
  kullanici_adi text not null,
  islem_turu text not null,
  randevu_tarihi timestamptz not null,
  hekim_adi text not null,
  klinik_adi text not null,
  adres text default '',
  notlar text default '',
  hatirlaticilar jsonb default '[]'::jsonb,
  takvim_senkron boolean default true,
  tamamlandi boolean default false,
  kontrol_listesi jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_dis_randevulari_cihaz_tarih
  on public.dis_randevulari (cihaz_id, randevu_tarihi);

-- Mevcut proje mimarisi (anon key + cihaz_id) ile uyumlu erişim politikası
alter table public.dis_randevulari enable row level security;

drop policy if exists "Allow anon access to dis_randevulari" on public.dis_randevulari;
create policy "Allow anon access to dis_randevulari"
  on public.dis_randevulari
  for all
  using (true)
  with check (true);
