import { supabase } from '../../lib/supabase'
import { loginEmail } from '../../lib/login'

export async function signIn(schoolCode: string, loginId: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({
    email: loginEmail(schoolCode, loginId),
    password,
  })
  if (error) {
    if (error.message === 'Invalid login credentials') {
      throw new Error('Wrong school code, ID or password.')
    }
    if (error.name === 'AuthRetryableFetchError' || error.message === 'Failed to fetch') {
      throw new Error("Can't reach the server. Check your internet connection and try again.")
    }
    throw new Error(error.message)
  }
}

export async function signOut() {
  await supabase.auth.signOut()
}

export async function getMyProfile(userId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, full_name_am, login_id, locale')
    .eq('id', userId)
    .single()
  if (error) throw error
  return data
}

export async function getMySchool() {
  const { data, error } = await supabase
    .from('schools')
    .select('id, code, name, name_am')
    .single()
  if (error) throw error
  return data
}
