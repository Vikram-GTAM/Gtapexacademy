import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { supabase } from "../lib/supabase";
import { authApi } from "../services";
import type { User } from "../types";

interface AuthState {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<User>;
  register: (name: string, email: string, password: string) => Promise<User>;
  logout: () => void;
  setUser: (u: User) => void;
}
const Ctx = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  // Restore a saved session (Supabase keeps it in localStorage and refreshes it automatically).
  useEffect(() => {
    supabase.auth.getSession().then(async ({ data }) => {
      if (data.session) setUser(await authApi.me().catch(() => null));
      setLoading(false);
    });
    // Signed out in another tab, or the session could not be refreshed.
    const { data: sub } = supabase.auth.onAuthStateChange((event) => { if (event === "SIGNED_OUT") setUser(null); });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    const onUnauthorized = () => { setUser(null); supabase.auth.signOut(); };
    window.addEventListener("lms:unauthorized", onUnauthorized);
    return () => window.removeEventListener("lms:unauthorized", onUnauthorized);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const r = await authApi.login({ email, password });
    setUser(r.user);
    return r.user;
  }, []);
  const register = useCallback(async (name: string, email: string, password: string) => {
    const r = await authApi.register({ name, email, password });
    setUser(r.user);
    return r.user;
  }, []);
  const logout = useCallback(() => { setUser(null); supabase.auth.signOut(); }, []);

  const value = useMemo(() => ({ user, loading, login, register, logout, setUser }), [user, loading, login, register, logout]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth() {
  const c = useContext(Ctx);
  if (!c) throw new Error("useAuth must be used inside AuthProvider");
  return c;
}
