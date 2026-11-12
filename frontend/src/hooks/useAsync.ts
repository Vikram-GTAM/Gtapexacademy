import { useCallback, useEffect, useRef, useState } from "react";
import { getErrorMessage } from "../services/api";

/** Run an async loader on mount / when deps change. Exposes loading + error + reload. */
export function useAsync<T>(loader: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const loaderRef = useRef(loader);
  loaderRef.current = loader;
  const seq = useRef(0);

  const run = useCallback(async (silent = false) => {
    const id = ++seq.current;
    if (!silent) setLoading(true);
    setError(null);
    try {
      const r = await loaderRef.current();
      if (id === seq.current) setData(r);
    } catch (e) {
      if (id === seq.current) setError(getErrorMessage(e));
    } finally {
      if (id === seq.current) setLoading(false);
    }
  }, []);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { run(); }, deps);
  return { data, loading, error, reload: () => run(true), reloadWithSpinner: () => run(false), setData };
}
