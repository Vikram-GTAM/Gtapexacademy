import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import type { Role } from "../types";
import { PageLoader } from "./ui";

export const homeFor = (role: Role) => (role === "admin" ? "/admin" : "/app");

export function ProtectedRoute({ role }: { role: Role }) {
  const { user, loading } = useAuth();
  const loc = useLocation();
  if (loading) return <PageLoader />;
  if (!user) return <Navigate to="/login" state={{ from: loc.pathname + loc.search }} replace />;
  if (user.role !== role) return <Navigate to={homeFor(user.role)} replace />;
  return <Outlet />;
}

/** Login/register pages: bounce signed-in users to their dashboard. */
export function GuestRoute() {
  const { user, loading } = useAuth();
  if (loading) return <PageLoader />;
  if (user) return <Navigate to={homeFor(user.role)} replace />;
  return <Outlet />;
}
