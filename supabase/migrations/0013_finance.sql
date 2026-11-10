-- 0013_finance.sql
-- Fees, invoices, payments, expenses, and fines & discipline (ቅጣት).
-- Money is ETB. Payments are never deleted, only voided with a reason.

create type public.fee_frequency  as enum ('once', 'monthly', 'semester', 'yearly');
create type public.invoice_status as enum ('unpaid', 'partial', 'paid', 'void');
create type public.payment_method as enum ('cash', 'bank', 'telebirr');
create type public.expense_category as enum
  ('salary', 'utilities', 'supplies', 'maintenance', 'transport', 'food', 'rent', 'other');
create type public.fine_kind   as enum ('late_payment', 'discipline', 'damage', 'lost_item', 'other');
create type public.fine_status as enum ('open', 'paid', 'waived');

-- ---------------------------------------------------------------------------
-- fee_types / fee_structures: what each grade pays.
-- ---------------------------------------------------------------------------
create table public.fee_types (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools (id),
  name       text not null,
  name_am    text,
  frequency  public.fee_frequency not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  constraint fee_types_school_name_key unique (school_id, name),
  constraint fee_types_school_id_id_key unique (school_id, id)
);
create index fee_types_created_by_idx on public.fee_types (created_by);

create table public.fee_structures (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools (id),
  academic_year_id uuid not null,
  grade_id         uuid not null,
  fee_type_id      uuid not null,
  amount           numeric(12, 2) not null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.profiles (id) on delete set null,
  constraint fee_structures_school_year_grade_type_key unique (school_id, academic_year_id, grade_id, fee_type_id),
  constraint fee_structures_amount_check check (amount >= 0),
  constraint fee_structures_year_fkey foreign key (school_id, academic_year_id)
    references public.academic_years (school_id, id),
  constraint fee_structures_grade_fkey foreign key (school_id, grade_id)
    references public.grades (school_id, id),
  constraint fee_structures_fee_type_fkey foreign key (school_id, fee_type_id)
    references public.fee_types (school_id, id)
);
create index fee_structures_school_grade_idx on public.fee_structures (school_id, grade_id);
create index fee_structures_school_fee_type_idx on public.fee_structures (school_id, fee_type_id);
create index fee_structures_created_by_idx on public.fee_structures (created_by);

-- ---------------------------------------------------------------------------
-- invoices: what a student must pay for a period. paid and status are kept
-- up to date by the payments trigger; nobody types them.
-- ---------------------------------------------------------------------------
create table public.invoices (
  id            uuid primary key default gen_random_uuid(),
  school_id     uuid not null references public.schools (id),
  invoice_no    text not null,
  enrollment_id uuid not null,
  fee_type_id   uuid,
  period        text not null,            -- e.g. "Hidar 2019"
  period_start  date not null,            -- first day of the Gregorian month, for charts
  due_date      date not null,
  total         numeric(12, 2) not null,
  discount      numeric(12, 2) not null default 0,
  paid          numeric(12, 2) not null default 0,
  status        public.invoice_status not null default 'unpaid',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references public.profiles (id) on delete set null,
  constraint invoices_school_invoice_no_key unique (school_id, invoice_no),
  constraint invoices_school_id_id_key unique (school_id, id),
  constraint invoices_amounts_check check (total >= 0 and discount >= 0 and discount <= total and paid >= 0),
  constraint invoices_enrollment_fkey foreign key (school_id, enrollment_id)
    references public.enrollments (school_id, id),
  constraint invoices_fee_type_fkey foreign key (school_id, fee_type_id)
    references public.fee_types (school_id, id)
);
create index invoices_school_enrollment_idx on public.invoices (school_id, enrollment_id);
create index invoices_school_period_idx on public.invoices (school_id, period_start, status);
create index invoices_school_fee_type_idx on public.invoices (school_id, fee_type_id);
create index invoices_created_by_idx on public.invoices (created_by);

-- ---------------------------------------------------------------------------
-- payments: cash, bank or Telebirr. Never deleted; void with a reason.
-- ---------------------------------------------------------------------------
create table public.payments (
  id           uuid primary key default gen_random_uuid(),
  school_id    uuid not null references public.schools (id),
  receipt_no   text not null,
  invoice_id   uuid not null,
  amount       numeric(12, 2) not null,
  method       public.payment_method not null,
  reference_no text,
  paid_on      date not null default current_date,
  received_by  uuid references public.profiles (id) on delete set null,
  voided_at    timestamptz,
  voided_by    uuid references public.profiles (id) on delete set null,
  void_reason  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  created_by   uuid references public.profiles (id) on delete set null,
  constraint payments_school_receipt_no_key unique (school_id, receipt_no),
  constraint payments_amount_check check (amount > 0),
  constraint payments_void_reason_check check (voided_at is null or nullif(btrim(void_reason), '') is not null),
  constraint payments_invoice_fkey foreign key (school_id, invoice_id)
    references public.invoices (school_id, id)
);
create index payments_school_invoice_idx on public.payments (school_id, invoice_id);
create index payments_school_paid_on_idx on public.payments (school_id, paid_on);
create index payments_received_by_idx on public.payments (received_by);
create index payments_voided_by_idx on public.payments (voided_by);
create index payments_created_by_idx on public.payments (created_by);

-- ---------------------------------------------------------------------------
-- expenses: what the school spends (salaries, power, water, supplies ...).
-- ---------------------------------------------------------------------------
create table public.expenses (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools (id),
  category    public.expense_category not null,
  description text not null,
  amount      numeric(12, 2) not null,
  spent_on    date not null default current_date,
  paid_to     text,
  method      public.payment_method not null default 'bank',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references public.profiles (id) on delete set null,
  constraint expenses_amount_check check (amount > 0)
);
create index expenses_school_spent_on_idx on public.expenses (school_id, spent_on);
create index expenses_created_by_idx on public.expenses (created_by);

-- ---------------------------------------------------------------------------
-- fines: ቅጣት — late-payment fines, discipline cases, damage, lost items.
-- amount 0 = a discipline record with no money involved.
-- ---------------------------------------------------------------------------
create table public.fines (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools (id),
  student_id uuid not null,
  kind       public.fine_kind not null,
  reason     text not null,
  amount     numeric(12, 2) not null default 0,
  issued_on  date not null default current_date,
  status     public.fine_status not null default 'open',
  issued_by  uuid references public.profiles (id) on delete set null,
  resolved_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  constraint fines_amount_check check (amount >= 0),
  constraint fines_student_fkey foreign key (school_id, student_id)
    references public.students (school_id, id)
);
create index fines_school_student_idx on public.fines (school_id, student_id);
create index fines_school_issued_on_idx on public.fines (school_id, issued_on);
create index fines_issued_by_idx on public.fines (issued_by);
create index fines_created_by_idx on public.fines (created_by);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create trigger fee_types_stamp before insert or update on public.fee_types
  for each row execute function private.stamp_row();
create trigger fee_structures_stamp before insert or update on public.fee_structures
  for each row execute function private.stamp_row();
create trigger invoices_stamp before insert or update on public.invoices
  for each row execute function private.stamp_row();
create trigger payments_stamp before insert or update on public.payments
  for each row execute function private.stamp_row();
create trigger expenses_stamp before insert or update on public.expenses
  for each row execute function private.stamp_row();
create trigger fines_stamp before insert or update on public.fines
  for each row execute function private.stamp_row();

create trigger fee_structures_audit after insert or update or delete on public.fee_structures
  for each row execute function private.audit_row();
create trigger invoices_audit after insert or update or delete on public.invoices
  for each row execute function private.audit_row();
create trigger payments_audit after insert or update or delete on public.payments
  for each row execute function private.audit_row();
create trigger expenses_audit after insert or update or delete on public.expenses
  for each row execute function private.audit_row();
create trigger fines_audit after insert or update or delete on public.fines
  for each row execute function private.audit_row();

-- Invoice and receipt numbers: INV-2019-000001, RCP-2019-000001.
-- (One function per table: PL/pgSQL cannot even read new.invoice_no on payments.)
create or replace function private.fill_invoice_no()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(btrim(new.invoice_no), '') = '' then
    new.invoice_no := private.next_number(new.school_id, 'invoice');
  end if;
  return new;
end;
$$;

create or replace function private.fill_receipt_no()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(btrim(new.receipt_no), '') = '' then
    new.receipt_no := private.next_number(new.school_id, 'receipt');
  end if;
  return new;
end;
$$;

-- invoice_no / receipt_no are filled before the NOT NULL check, so let them default to ''.
alter table public.invoices alter column invoice_no set default '';
alter table public.payments alter column receipt_no set default '';

create trigger invoices_fill_no before insert on public.invoices
  for each row execute function private.fill_invoice_no();
create trigger payments_fill_no before insert on public.payments
  for each row execute function private.fill_receipt_no();

-- A payment can only be voided, never changed or deleted; who received it is the signed-in user.
create or replace function private.guard_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Payments cannot be deleted. Void them with a reason' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.received_by := (select p.id from public.profiles p where p.id = auth.uid());
    end if;
    new.voided_at := null; new.voided_by := null; new.void_reason := null;
    return new;
  end if;
  -- UPDATE: only voiding is allowed, and only once.
  if (new.invoice_id, new.amount, new.method, new.reference_no, new.paid_on, new.receipt_no)
     is distinct from (old.invoice_id, old.amount, old.method, old.reference_no, old.paid_on, old.receipt_no)
     or old.voided_at is not null then
    raise exception 'A payment cannot be changed. Void it and record a new one' using errcode = '42501';
  end if;
  if new.voided_at is not null then
    new.voided_by := (select p.id from public.profiles p where p.id = auth.uid());
  end if;
  return new;
end;
$$;

create trigger payments_guard before insert or update or delete on public.payments
  for each row execute function private.guard_payment();

-- Keep invoices.paid and status in step with the payments; refuse overpayment.
create or replace function private.sync_invoice()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv  public.invoices;
  v_paid numeric(12, 2);
begin
  select * into v_inv from public.invoices
  where school_id = new.school_id and id = new.invoice_id
  for update;

  select coalesce(sum(p.amount), 0) into v_paid
  from public.payments p
  where p.school_id = new.school_id and p.invoice_id = new.invoice_id and p.voided_at is null;

  if v_inv.status = 'void' and tg_op = 'INSERT' then
    raise exception 'Invoice % is void', v_inv.invoice_no using errcode = '23514';
  end if;
  if v_paid > v_inv.total - v_inv.discount then
    raise exception 'Payment is more than invoice % still owes (% ETB)', v_inv.invoice_no,
      v_inv.total - v_inv.discount - (v_paid - new.amount) using errcode = '23514';
  end if;

  update public.invoices
     set paid = v_paid,
         status = case when status = 'void' then 'void'::public.invoice_status
                       when v_paid >= total - discount then 'paid'
                       when v_paid > 0 then 'partial'
                       else 'unpaid' end
   where school_id = new.school_id and id = new.invoice_id;
  return null;
end;
$$;

create trigger payments_sync_invoice after insert or update on public.payments
  for each row execute function private.sync_invoice();

revoke execute on function private.fill_invoice_no() from public, anon, authenticated;
revoke execute on function private.fill_receipt_no() from public, anon, authenticated;
revoke execute on function private.guard_payment() from public, anon, authenticated;
revoke execute on function private.sync_invoice() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.fee_types      enable row level security;
alter table public.fee_structures enable row level security;
alter table public.invoices       enable row level security;
alter table public.payments       enable row level security;
alter table public.expenses       enable row level security;
alter table public.fines          enable row level security;

-- Fee lists: everyone in the school reads (parents see what a grade costs).
create policy fee_types_select on public.fee_types for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy fee_types_insert on public.fee_types for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy fee_types_update on public.fee_types for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));

create policy fee_structures_select on public.fee_structures for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy fee_structures_insert on public.fee_structures for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy fee_structures_update on public.fee_structures for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy fee_structures_delete on public.fee_structures for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')));

-- invoices: finance side reads all; students and parents read their own.
create policy invoices_select on public.invoices for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or exists (select 1 from public.enrollments e
                 where e.school_id = invoices.school_id and e.id = invoices.enrollment_id
                   and e.student_id = any ((select public.my_student_ids())::uuid[]))
    )
  );
create policy invoices_insert on public.invoices for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy invoices_update on public.invoices for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));

-- payments: same readers as invoices; finance records and voids. No DELETE policy.
create policy payments_select on public.payments for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or exists (select 1 from public.invoices i
                 join public.enrollments e on e.school_id = i.school_id and e.id = i.enrollment_id
                 where i.school_id = payments.school_id and i.id = payments.invoice_id
                   and e.student_id = any ((select public.my_student_ids())::uuid[]))
    )
  );
create policy payments_insert on public.payments for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy payments_update on public.payments for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));

-- expenses: finance, director and super admin only. No DELETE policy.
create policy expenses_select on public.expenses for select to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,director,finance}')));
create policy expenses_insert on public.expenses for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy expenses_update on public.expenses for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));

-- fines: office roles read all; a teacher reads and records for own students;
-- students and parents read their own.
create policy fines_select on public.fines for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or student_id = any ((select public.teacher_student_ids())::uuid[])
      or student_id = any ((select public.my_student_ids())::uuid[])
    )
  );
create policy fines_insert on public.fines for insert to authenticated
  with check (
    school_id = (select public.current_school_id())
    and ((select public.has_any_role('{super_admin,registrar,finance}'))
         or student_id = any ((select public.teacher_student_ids())::uuid[]))
  );
create policy fines_update on public.fines for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar,finance}')));

-- Who issued a fine is the signed-in user.
create or replace function private.fill_fine_issuer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    new.issued_by := (select p.id from public.profiles p where p.id = auth.uid());
  end if;
  return new;
end;
$$;
create trigger fines_fill_issuer before insert on public.fines
  for each row execute function private.fill_fine_issuer();
revoke execute on function private.fill_fine_issuer() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

-- Fee balance per enrollment.
create view public.v_fee_balance
with (security_invoker = true)
as
select i.school_id,
       i.enrollment_id,
       sum(i.total - i.discount) filter (where i.status <> 'void')::numeric(12, 2)          as billed,
       sum(i.paid) filter (where i.status <> 'void')::numeric(12, 2)                         as paid,
       sum(i.total - i.discount - i.paid) filter (where i.status <> 'void')::numeric(12, 2) as balance,
       count(*) filter (where i.status in ('unpaid', 'partial'))::int                       as open_invoices
from public.invoices i
group by i.school_id, i.enrollment_id;

-- Money in and out per month.
create view public.v_monthly_finance
with (security_invoker = true)
as
with months as (
  select school_id, date_trunc('month', paid_on)::date as month, sum(amount) as revenue, 0::numeric as expenses
  from public.payments where voided_at is null
  group by 1, 2
  union all
  select school_id, date_trunc('month', spent_on)::date, 0, sum(amount)
  from public.expenses
  group by 1, 2
)
select school_id, month,
       sum(revenue)::numeric(14, 2)  as revenue,
       sum(expenses)::numeric(14, 2) as expenses,
       (sum(revenue) - sum(expenses))::numeric(14, 2) as net
from months
group by school_id, month;

revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
revoke insert, update, delete, truncate on public.audit_log from authenticated, service_role;
