// Ethiopian phone numbers are stored as +251 and 9 digits (public.phone_et).
// Accepts 0911 22 33 44, 911223344, 251911223344, +251-911-223344 ...
const PHONE = /^(?:\+?251|0)?([1-9]\d{8})$/

export function toE164(raw: string): string | null {
  const digits = raw.replace(/[\s\-().]/g, '')
  const m = PHONE.exec(digits)
  return m ? `+251${m[1]}` : null
}

export function formatPhone(e164: string | null | undefined): string {
  if (!e164) return ''
  const m = /^\+251(\d{3})(\d{3})(\d{3})$/.exec(e164)
  return m ? `+251 ${m[1]} ${m[2]} ${m[3]}` : e164
}
