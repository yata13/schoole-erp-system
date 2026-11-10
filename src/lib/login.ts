import { toE164 } from './phone'

// Login = school code + student ID or phone + password.
// Supabase Auth needs an email, so the app turns the login into a hidden one:
//   AHS + AHS-19-0001  ->  ahs-19-0001@ahs.erp.local
//   AHS + 0911223344   ->  251911223344@ahs.erp.local
// The create-users Edge Function must build emails with exactly this rule.

/** The login ID as stored in profiles.login_id: upper case, phones as +251... */
export function normalizeLoginId(raw: string): string {
  const phone = toE164(raw)
  return phone ?? raw.trim().toUpperCase()
}

export function loginEmail(schoolCode: string, loginId: string): string {
  const local = normalizeLoginId(loginId).replace(/^\+/, '').toLowerCase()
  return `${local}@${schoolCode.trim().toLowerCase()}.erp.local`
}
